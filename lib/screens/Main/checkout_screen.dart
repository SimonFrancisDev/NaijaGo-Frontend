import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../constants.dart';
import '../../providers/cart_provider.dart';
import '../../services/payment_service.dart';
import '../../models/address.dart';
import 'package:flutterwave_standard/flutterwave.dart';

// Colors
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;

// =========================================================================
// NEW: Backend-driven Order Summary Models
// =========================================================================

/// Helper class to hold summary data for a single vendor's shipment.
class ShipmentSummary {
  final String vendorName;
  final double subtotal;
  final double shippingPrice;
  final double platformFee;
  final List<Map<String, dynamic>> items;
  final String vendorId; 
  final double vendorLatitude;
  final double vendorLongitude;

  ShipmentSummary({
    required this.vendorName,
    required this.subtotal,
    required this.shippingPrice,
    required this.platformFee,
    required this.items,
    required this.vendorId, 
    required this.vendorLatitude, 
    required this.vendorLongitude,
  });

  factory ShipmentSummary.fromJson(Map<String, dynamic> json) {
    return ShipmentSummary(
      vendorName: json['vendorName'] ?? 'Unknown Vendor',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingPrice: (json['shippingPrice'] as num?)?.toDouble() ?? 0.0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      vendorId: json['vendorId'] as String? ?? '', 
      vendorLatitude: (json['vendorLocation']['latitude'] as num?)?.toDouble() ?? 0.0,
      vendorLongitude: (json['vendorLocation']['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorName': vendorName,
      'subtotal': subtotal,
      'shippingPrice': shippingPrice,
      'platformFee': platformFee,
      'items': items,
      'vendor': vendorId, // Mongoose requires key 'vendor' for the ID
      'vendorLocation': {
        'latitude': vendorLatitude,
        'longitude': vendorLongitude,
      },
    };
  }
}

/// The main class to hold the complete, backend-calculated order summary.
class FullOrderSummary {
  final double totalSubtotal;
  final double totalShippingPrice;
  final double totalPlatformFees;
  final double taxPrice;
  final double totalPrice;
  final List<ShipmentSummary> shipmentSummaries;

  FullOrderSummary({
    required this.totalSubtotal,
    required this.totalShippingPrice,
    required this.totalPlatformFees,
    required this.taxPrice,
    required this.totalPrice,
    required this.shipmentSummaries,
  });

  factory FullOrderSummary.fromJson(Map<String, dynamic> json) {
    return FullOrderSummary(
      totalSubtotal: (json['totalSubtotal'] as num?)?.toDouble() ?? 0.0,
      totalShippingPrice: (json['totalShippingPrice'] as num?)?.toDouble() ?? 0.0,
      totalPlatformFees: (json['totalPlatformFees'] as num?)?.toDouble() ?? 0.0,
      taxPrice: (json['taxPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      shipmentSummaries: (json['shipmentSummaries'] as List<dynamic>?)
          ?.map((e) => ShipmentSummary.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

// =========================================================================
// CheckoutScreen State
// =========================================================================

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onOrderSuccess;

  const CheckoutScreen({required this.onOrderSuccess, super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  bool _useSavedAddress = false;
  Address? _selectedAddress;
  List<Address> _userAddresses = [];

  bool _addressSelectedOrFetched = false;

  String? _selectedPaymentMethod = 'Card';

  double _walletBalance = 0.0;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Position? _currentPosition;
  double? _userLatitude;
  double? _userLongitude;

  FullOrderSummary? _fullOrderSummary;
  bool _isSummaryCalculated = false;

  @override
  void initState() {
    super.initState();
    _fetchAddressesAndWallet();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressesAndWallet() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> addressesJson = responseData['deliveryAddresses'] ?? [];

        // FIXED: Use 'userWalletBalance' instead of 'walletBalance'
        final double wallet = (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          _userAddresses = addressesJson.map((json) => Address.fromJson(json)).toList();
          _walletBalance = wallet; // Now correctly reads buyer wallet

          if (_userAddresses.isNotEmpty) {
            _selectedAddress = _userAddresses.firstWhere(
              (addr) => addr.isDefault,
              orElse: () => _userAddresses.first,
            );
            _useSavedAddress = true;
            _addressSelectedOrFetched = true;
          }
        });
        
        await _ensureUserLocation(shouldFetchSummary: true);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // The rest of your code remains exactly the same...
  // ( _fetchOrderSummary, _fetchCurrentLocation, _ensureUserLocation, _placeOrder, build, etc.)

  Future<void> _fetchOrderSummary() async {
    if (!_addressSelectedOrFetched) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSummaryCalculated = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    if (token == null) {
      _showSnackBar('Authentication token not found.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final List<Map<String, dynamic>> orderItems =
          cartProvider.items.values.map((item) => item.toJson()).toList();

      final Uri url = Uri.parse('$baseUrl/api/orders/summary');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'cartItems': orderItems,
          'shippingAddress': _useSavedAddress
           ? _selectedAddress!.toJson()
           : {
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'postalCode': _postalCodeController.text.trim(),
            'country': _countryController.text.trim(),
           },
          'userLocation': {
            'latitude': _userLatitude,
            'longitude': _userLongitude,
          },
        }),
      );

      final Map<String, dynamic> responseData = _safeJson(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _fullOrderSummary = FullOrderSummary.fromJson(responseData);
          _isSummaryCalculated = true;
          _errorMessage = null;
        });
        print('✅ Summary fetched: Total Price ₦${_fullOrderSummary?.totalPrice.toStringAsFixed(2)}');
      } else {
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to fetch order summary.';
          _fullOrderSummary = null;
          _isSummaryCalculated = false;
        });
        print('🛑 Summary fetch failed: ${response.statusCode} - $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error while fetching summary: $e';
        _fullOrderSummary = null;
        _isSummaryCalculated = false;
      });
      print('❌ Summary fetch catch error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoading = true);
    setState(() {
      _useSavedAddress = false;
      _selectedAddress = null;
      _addressSelectedOrFetched = false;
      _isSummaryCalculated = false;
      _fullOrderSummary = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      Placemark place = placemarks.first;

      _addressController.text = '${place.street}, ${place.subLocality}';
      _cityController.text = place.locality ?? '';
      _postalCodeController.text = place.postalCode ?? '';
      _countryController.text = place.country ?? '';

      setState(() {
        _addressSelectedOrFetched = true;
        _currentPosition = position;
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });
      _showSnackBar('Location fetched successfully! Calculating delivery fee...');

      await _fetchOrderSummary();
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      setState(() {
        _addressSelectedOrFetched = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _ensureUserLocation({bool shouldFetchSummary = false}) async {
    if (_userLatitude != null && _userLongitude != null) {
      if (shouldFetchSummary) {
        await _fetchOrderSummary();
      }
      return true;
    }

    if (_useSavedAddress && _selectedAddress != null) {
      try {
        final dyn = _selectedAddress as dynamic;
        final lat = dyn.latitude;
        final lon = dyn.longitude;
        if (lat != null && lon != null) {
          _userLatitude = (lat as num).toDouble();
          _userLongitude = (lon as num).toDouble();
          if (shouldFetchSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (_) {}

      final String combined =
          '${_selectedAddress!.fullAddress}, ${_selectedAddress!.city ?? ''}, ${_selectedAddress!.country ?? ''}';
      try {
        final List<Location> locations = await locationFromAddress(combined);
        if (locations.isNotEmpty) {
          _userLatitude = locations.first.latitude;
          _userLongitude = locations.first.longitude;
          if (shouldFetchSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        print('Forward geocoding failed for saved address: $e');
      }
    }

    final String builtAddress = '${_addressController.text}, ${_cityController.text}, ${_countryController.text}';
    if (builtAddress.trim().isNotEmpty) {
      try {
        final List<Location> locations = await locationFromAddress(builtAddress);
        if (locations.isNotEmpty) {
          _userLatitude = locations.first.latitude;
          _userLongitude = locations.first.longitude;
          if (shouldFetchSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        print('Forward geocoding failed for built address: $e');
      }
    }

    return false;
  }

  Future<void> _placeOrder() async {
    if (!_addressSelectedOrFetched) {
      _showSnackBar('Please select your address by clicking one of the location buttons.');
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method.');
      return;
    }

    if (!_isSummaryCalculated || _fullOrderSummary == null) {
      _showSnackBar('Please wait for the delivery fee to be calculated or choose an address.');
      return;
    }

    setState(() => _isLoading = true);

    final bool hasCoords = await _ensureUserLocation();
    if (!hasCoords) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to determine delivery coordinates.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      if (token == null) {
        setState(() => _errorMessage = 'Authentication token not found.');
        return;
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.items.isEmpty) {
        setState(() => _errorMessage = 'Your cart is empty.');
        return;
      }

      final List<Map<String, dynamic>> orderItems =
          cartProvider.items.values.map((item) => item.toJson()).toList();

      final missingVendor = orderItems.any((i) => i['vendor'] == null);
      if (missingVendor) {
        setState(() => _errorMessage = 'Missing vendor info.');
        return;
      }

      final FullOrderSummary summary = _fullOrderSummary!;
      final double totalPrice = summary.totalPrice;

      if (_selectedPaymentMethod == 'Wallet Balance') {
        if (_walletBalance < totalPrice) {
          setState(() => _errorMessage = 'Insufficient wallet balance.');
          return;
        }
      }

      final Map<String, dynamic> requestBody = {
        'orderItems': orderItems,
        'shippingAddress': _useSavedAddress
            ? _selectedAddress!.toJson()
            : {
                'address': _addressController.text.trim(),
                'city': _cityController.text.trim(),
                'postalCode': _postalCodeController.text.trim(),
                'country': _countryController.text.trim(),
              },
        'paymentMethod': _selectedPaymentMethod,
        'totalShippingPrice': summary.totalShippingPrice,
        'totalPlatformFees': summary.totalPlatformFees,
        'taxPrice': summary.taxPrice,
        'totalPrice': totalPrice,
        'userLocation': {
          'latitude': _userLatitude,
          'longitude': _userLongitude,
        },
        'shipmentSummaries': summary.shipmentSummaries.map((s) => s.toJson()).toList(),
      };

      final createOrderUrl = Uri.parse('$baseUrl/api/orders');
      final createOrderResp = await http.post(
        createOrderUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> createOrderData = _safeJson(createOrderResp.body);

      if (createOrderResp.statusCode != 201) {
        setState(() => _errorMessage = createOrderData['message'] ?? 'Failed to place order.');
        return;
      }

      final String orderId = createOrderData['_id'];

      if (_selectedPaymentMethod == 'Wallet Balance') {
        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token'
          },
        );

        if (payResp.statusCode == 200) {
          setState(() => _successMessage = 'Order placed using Wallet!');
          cartProvider.clearCart();
          await _fetchAddressesAndWallet(); // Refresh wallet
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          setState(() => _errorMessage = payData['message'] ?? 'Wallet payment failed.');
        }
      } else {
        final userEmail = prefs.getString('email') ?? 'customer@example.com';
        final fullName = prefs.getString('fullName') ?? 'Test User';
        final phone = prefs.getString('phoneNumber') ?? '08012345678';

        final paymentService = PaymentService();
        final chargeResponse = await paymentService.startFlutterwavePayment(
          context: context,
          amount: totalPrice,
          email: userEmail,
          name: fullName,
          phoneNumber: phone,
        );

        if (chargeResponse == null) {
          setState(() => _errorMessage = 'Payment not initiated.');
          return;
        }

        final String fwStatus = (chargeResponse.status ?? '').toLowerCase();

        if (fwStatus == 'cancelled') {
          setState(() => _errorMessage = 'Payment cancelled.');
          return;
        }

        final String? paymentId = chargeResponse.transactionId ?? chargeResponse.txRef;

        if (paymentId == null) {
          setState(() => _errorMessage = 'Missing transaction reference.');
          return;
        }

        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({
            'transaction_id': paymentId,
            'status': chargeResponse.status,
            'update_time': DateTime.now().toIso8601String(),
            'email_address': userEmail,
          }),
        );

        if (payResp.statusCode == 200) {
          setState(() => _successMessage = 'Order placed and paid!');
          cartProvider.clearCart();
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          setState(() => _errorMessage = payData['message'] ?? 'Payment confirmation failed.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final FullOrderSummary? currentSummary = _fullOrderSummary;

    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(color: greenYellow)),
        backgroundColor: deepNavyBlue,
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Shipping Address',
                style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _fetchCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_useSavedAddress && _addressSelectedOrFetched
                            ? deepNavyBlue
                            : deepNavyBlue.withOpacity(0.1),
                        foregroundColor: !_useSavedAddress && _addressSelectedOrFetched
                            ? greenYellow
                            : deepNavyBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current Location'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        _addressController.clear();
                        _cityController.clear();
                        _postalCodeController.clear();
                        _countryController.clear();

                        final selected = await _showAddressSelectionDialog();
                        if (selected != null) {
                          setState(() {
                            _selectedAddress = selected;
                            _useSavedAddress = true;
                            _addressSelectedOrFetched = true;
                          });
                          await _ensureUserLocation(shouldFetchSummary: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _useSavedAddress && _selectedAddress != null
                            ? deepNavyBlue
                            : deepNavyBlue.withOpacity(0.1),
                        foregroundColor: _useSavedAddress && _selectedAddress != null
                            ? greenYellow
                            : deepNavyBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.location_on),
                      label: const Text('Saved Address'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_addressSelectedOrFetched && _useSavedAddress && _selectedAddress != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: deepNavyBlue,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected Address:', style: TextStyle(color: greenYellow.withOpacity(0.7), fontSize: 16)),
                        const SizedBox(height: 5),
                        Text(_selectedAddress!.fullAddress, style: const TextStyle(fontSize: 18, color: whiteBackground)),
                        Text('${_selectedAddress!.city}, ${_selectedAddress!.postalCode}, ${_selectedAddress!.country}',
                            style: const TextStyle(fontSize: 16, color: whiteBackground)),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      _addressSelectedOrFetched ? 'Location Ready' : 'Select delivery address above',
                      style: TextStyle(color: _addressSelectedOrFetched ? deepNavyBlue : Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(controller: _addressController, decoration: _inputDecoration('Address'), enabled: false),
                    const SizedBox(height: 15),
                    TextFormField(controller: _cityController, decoration: _inputDecoration('City'), enabled: false),
                    const SizedBox(height: 15),
                    TextFormField(controller: _postalCodeController, decoration: _inputDecoration('Postal Code'), enabled: false),
                    const SizedBox(height: 15),
                    TextFormField(controller: _countryController, decoration: _inputDecoration('Country'), enabled: false),
                  ],
                ),

              const SizedBox(height: 30),

              const Text('Payment Method', style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: _inputDecoration('Select Payment Method').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                ),
                dropdownColor: deepNavyBlue.withOpacity(0.9),
                style: const TextStyle(color: greenYellow),
                items: [
                  'Card',
                  'Bank Transfer',
                  'Wallet Balance (₦${_walletBalance.toStringAsFixed(0)})'
                ].map((method) => DropdownMenuItem<String>(
                      value: method.contains('Wallet Balance') ? 'Wallet Balance' : method,
                      child: Text(method),
                    )).toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                validator: (value) => value == null ? 'Select payment method' : null,
              ),
              const SizedBox(height: 30),

              const Text('Order Summary', style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              if (_isLoading && !_isSummaryCalculated)
                const Center(child: CircularProgressIndicator(color: deepNavyBlue))
              else if (_isSummaryCalculated && currentSummary != null)
                _buildFullSummaryCard(currentSummary, cartProvider)
              else
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Select address to calculate final amount',
                    style: TextStyle(color: deepNavyBlue),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 30),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (cartProvider.itemCount > 0 &&
                                _addressSelectedOrFetched &&
                                _isSummaryCalculated &&
                                _selectedPaymentMethod != null)
                            ? _placeOrder
                            : null,
                        icon: const Icon(Icons.check_circle, color: deepNavyBlue),
                        label: const Text('Place Order', style: TextStyle(color: deepNavyBlue, fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenYellow,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullSummaryCard(FullOrderSummary summary, CartProvider cartProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: deepNavyBlue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.shipmentSummaries.length > 1) ...[
              Text('Breakdown by Vendor:', style: TextStyle(color: greenYellow.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...summary.shipmentSummaries.map((shipment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📦 ${shipment.vendorName} Shipment:', style: const TextStyle(color: greenYellow, fontWeight: FontWeight.bold)),
                        _buildSummaryRow('  - Item Subtotal:', '₦${shipment.subtotal.toStringAsFixed(2)}'),
                        _buildSummaryRow('  - Delivery Fee:', '₦${shipment.shippingPrice.toStringAsFixed(2)}'),
                        _buildSummaryRow('  - Platform Fee:', '₦${shipment.platformFee.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
              const Divider(height: 30, thickness: 0.5, color: greenYellow),
            ],
            _buildSummaryRow('Total Items Subtotal (${cartProvider.itemCount} items):', '₦${summary.totalSubtotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Total Delivery Fees:', '₦${summary.totalShippingPrice.toStringAsFixed(2)}'),
            if (summary.taxPrice > 0) _buildSummaryRow('Tax Price:', '₦${summary.taxPrice.toStringAsFixed(2)}'),
            const Divider(height: 30, thickness: 1, color: greenYellow),
            _buildTotalRow('Grand Total:', '₦${summary.totalPrice.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: whiteBackground)),
          Text(value, style: const TextStyle(fontSize: 16, color: whiteBackground)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: whiteBackground)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: greenYellow)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: deepNavyBlue),
      filled: true,
      fillColor: deepNavyBlue.withOpacity(0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: deepNavyBlue, width: 2)),
    );
  }

  Future<Address?> _showAddressSelectionDialog() async {
    if (_userAddresses.isEmpty) {
      _showSnackBar('No saved addresses.');
      return null;
    }
    return showDialog<Address>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Delivery Address'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _userAddresses.length,
            itemBuilder: (context, index) {
              final address = _userAddresses[index];
              return ListTile(
                title: Text(address.fullAddress),
                subtitle: Text('${address.city}, ${address.country}'),
                onTap: () => Navigator.pop(context, address),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      print('Warning: Failed to decode JSON: $body');
      return {};
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';

// import '../../constants.dart';
// import '../../providers/cart_provider.dart';
// import '../../services/payment_service.dart';
// import '../../models/address.dart';
// import 'package:flutterwave_standard/flutterwave.dart';

// // Colors
// const Color deepNavyBlue = Color(0xFF000080);
// const Color greenYellow = Color(0xFFADFF2F);
// const Color whiteBackground = Colors.white;

// // =========================================================================
// // NEW: Backend-driven Order Summary Models
// // =========================================================================

// /// Helper class to hold summary data for a single vendor's shipment.
// class ShipmentSummary {
//   final String vendorName;
//   final double subtotal;
//   final double shippingPrice;
//   final double platformFee;
//   final List<Map<String, dynamic>> items;
//   final String vendorId; 
//   final double vendorLatitude;
//   final double vendorLongitude;

//   ShipmentSummary({
//     required this.vendorName,
//     required this.subtotal,
//     required this.shippingPrice,
//     required this.platformFee,
//     required this.items,
//     required this.vendorId, 
//     required this.vendorLatitude, 
//     required this.vendorLongitude,
//   });

//   factory ShipmentSummary.fromJson(Map<String, dynamic> json) {
//   return ShipmentSummary(
//     vendorName: json['vendorName'] ?? 'Unknown Vendor',
//     subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
//     shippingPrice: (json['shippingPrice'] as num?)?.toDouble() ?? 0.0,
//     platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
//     items: (json['items'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    
//     // 💥 FIX IS HERE: Change 'vendor' to the correct key 'vendorId'
//     vendorId: json['vendorId'] as String? ?? '', 
    
//     vendorLatitude: (json['vendorLocation']['latitude'] as num?)?.toDouble() ?? 0.0,
//     vendorLongitude: (json['vendorLocation']['longitude'] as num?)?.toDouble() ?? 0.0,
//   );
// }

//   Map<String, dynamic> toJson() {
//     return {
//       'vendorName': vendorName,
//       'subtotal': subtotal,
//       'shippingPrice': shippingPrice,
//       'platformFee': platformFee,
//       'items': items,
//       'vendor': vendorId, // Mongoose requires key 'vendor' for the ID
//       'vendorLocation': {
//         'latitude': vendorLatitude,
//         'longitude': vendorLongitude,
//       },
//     };
//   }
// }

// /// The main class to hold the complete, backend-calculated order summary.
// class FullOrderSummary {
//   final double totalSubtotal;
//   final double totalShippingPrice;
//   final double totalPlatformFees;
//   final double taxPrice;
//   final double totalPrice;
//   final List<ShipmentSummary> shipmentSummaries;

//   FullOrderSummary({
//     required this.totalSubtotal,
//     required this.totalShippingPrice,
//     required this.totalPlatformFees,
//     required this.taxPrice,
//     required this.totalPrice,
//     required this.shipmentSummaries,
//   });

//   factory FullOrderSummary.fromJson(Map<String, dynamic> json) {
//     return FullOrderSummary(
//       totalSubtotal: (json['totalSubtotal'] as num?)?.toDouble() ?? 0.0,
//       totalShippingPrice: (json['totalShippingPrice'] as num?)?.toDouble() ?? 0.0,
//       totalPlatformFees: (json['totalPlatformFees'] as num?)?.toDouble() ?? 0.0,
//       taxPrice: (json['taxPrice'] as num?)?.toDouble() ?? 0.0,
//       totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
//       shipmentSummaries: (json['shipmentSummaries'] as List<dynamic>?)
//           ?.map((e) => ShipmentSummary.fromJson(e as Map<String, dynamic>))
//           .toList() ?? [],
//     );
//   }
// }

// // =========================================================================
// // CheckoutScreen State
// // =========================================================================

// class CheckoutScreen extends StatefulWidget {
//   final VoidCallback onOrderSuccess;

//   const CheckoutScreen({required this.onOrderSuccess, super.key});

//   @override
//   State<CheckoutScreen> createState() => _CheckoutScreenState();
// }

// class _CheckoutScreenState extends State<CheckoutScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _addressController = TextEditingController();
//   final TextEditingController _cityController = TextEditingController();
//   final TextEditingController _postalCodeController = TextEditingController();
//   final TextEditingController _countryController = TextEditingController();

//   // New state variables for address selection
//   bool _useSavedAddress = false; // False implies manual/current location entry
//   Address? _selectedAddress;
//   List<Address> _userAddresses = [];

//   // State to track if an address has been successfully selected/fetched
//   bool _addressSelectedOrFetched = false;

//   // Payment method selection
//   String? _selectedPaymentMethod = 'Card'; // Default to 'Card'

//   // State variable to hold user wallet balance
//   double _walletBalance = 0.0;

//   bool _isLoading = false;
//   String? _errorMessage;
//   String? _successMessage;

//   // NEW STATE: Store last fetched Position and user coordinates to send to backend
//   Position? _currentPosition;
//   double? _userLatitude;
//   double? _userLongitude;

//   // ⚠️ MODIFIED/NEW STATE: Store backend-calculated summary
//   FullOrderSummary? _fullOrderSummary;
//   bool _isSummaryCalculated = false;

//   @override
//   void initState() {
//     super.initState();
//     _fetchAddressesAndWallet();
//   }

//   @override
//   void dispose() {
//     _addressController.dispose();
//     _cityController.dispose();
//     _postalCodeController.dispose();
//     _countryController.dispose();
//     super.dispose();
//   }

//   // ⚠️ MODIFICATION 1: REMOVED the local `_calculateOrderSummary` method

//   Future<void> _fetchAddressesAndWallet() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     if (token == null) {
//       // Cannot fetch user data without token
//       return;
//     }

//     try {
//       final Uri url = Uri.parse('$baseUrl/api/auth/me');
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Bearer $token'
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         final List<dynamic> addressesJson =
//             responseData['deliveryAddresses'] ?? [];

//         final double wallet =
//             (responseData['walletBalance'] as num?)?.toDouble() ?? 0.0;

//         setState(() {
//           _userAddresses =
//               addressesJson.map((json) => Address.fromJson(json)).toList();
//           _walletBalance = wallet; // Store wallet balance

//           if (_userAddresses.isNotEmpty) {
//             _selectedAddress = _userAddresses.firstWhere(
//               (addr) => addr.isDefault,
//               orElse: () => _userAddresses.first,
//             );
//             // If there's a default address, set initial state to use it
//             _useSavedAddress = true;
//             _addressSelectedOrFetched = true;
//           }
//         });
        
//         // After fetching addresses and setting the initial one, fetch the summary
//         await _ensureUserLocation(shouldFetchSummary: true);
//       }
//     } catch (e) {
//       print('Error fetching user data: $e');
//     }
//   }

//   // ⚠️ NEW METHOD: Calculate Order Summary from Backend
//   Future<void> _fetchOrderSummary() async {
//     if (!_addressSelectedOrFetched) return;
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);
//     if (cartProvider.items.isEmpty) return;

//     setState(() {
//       _isLoading = true;
//       _isSummaryCalculated = false;
//     });

//     final prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');
//     if (token == null) {
//       _showSnackBar('Authentication token not found.');
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final List<Map<String, dynamic>> orderItems =
//           cartProvider.items.values.map((item) => item.toJson()).toList();

//       final Uri url = Uri.parse('$baseUrl/api/orders/summary');
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Bearer $token'
//         },
//         body: jsonEncode({
//           'cartItems': orderItems,
//           'shippingAddress': _useSavedAddress
//            ? _selectedAddress!.toJson()
//            : {
//             'address': _addressController.text.trim(),
//             'city': _cityController.text.trim(),
//             'postalCode': _postalCodeController.text.trim(),
//             'country': _countryController.text.trim(),
//            },
//           'userLocation': {
//             'latitude': _userLatitude,
//             'longitude': _userLongitude,
//           },
//         }),
//       );

//       final Map<String, dynamic> responseData = _safeJson(response.body);

//       if (response.statusCode == 200) {
//         setState(() {
//           _fullOrderSummary = FullOrderSummary.fromJson(responseData);
//           _isSummaryCalculated = true;
//           _errorMessage = null;
//         });
//         print('✅ Summary fetched: Total Price ₦${_fullOrderSummary?.totalPrice.toStringAsFixed(2)}');
//       } else {
//         setState(() {
//           _errorMessage =
//               responseData['message'] ?? 'Failed to fetch order summary.';
//           _fullOrderSummary = null;
//           _isSummaryCalculated = false;
//         });
//         print('🛑 Summary fetch failed: ${response.statusCode} - $_errorMessage');
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Network error while fetching summary: $e';
//         _fullOrderSummary = null;
//         _isSummaryCalculated = false;
//       });
//       print('❌ Summary fetch catch error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchCurrentLocation() async {
//     setState(() => _isLoading = true);
//     // Reset saved address state
//     setState(() {
//       _useSavedAddress = false;
//       _selectedAddress = null;
//       _addressSelectedOrFetched = false; // Reset before fetch
//       _isSummaryCalculated = false;
//       _fullOrderSummary = null;
//     });

//     try {
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           _showSnackBar('Location permissions are denied.');
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         _showSnackBar('Location permissions are permanently denied.');
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high);
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//           position.latitude, position.longitude);
//       Placemark place = placemarks.first;

//       _addressController.text = '${place.street}, ${place.subLocality}';
//       _cityController.text = place.locality ?? '';
//       _postalCodeController.text = place.postalCode ?? '';
//       _countryController.text = place.country ?? '';

//       // MARK ADDRESS AS FETCHED
//       setState(() {
//         _addressSelectedOrFetched = true;
//         // Store the fetched position for sending to backend
//         _currentPosition = position;
//         _userLatitude = position.latitude;
//         _userLongitude = position.longitude;
//       });
//       _showSnackBar('Location fetched successfully! Calculating delivery fee...');

//       // ⚠️ MODIFICATION 2: Call fetch summary after successful location fetch
//       await _fetchOrderSummary();

//     } catch (e) {
//       _showSnackBar('Failed to get current location: $e');
//       setState(() {
//         _addressSelectedOrFetched = false;
//       });
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//     }
//   }

//   /// Ensures we have user latitude & longitude.
//   /// New parameter added to conditionally trigger summary fetch.
//   Future<bool> _ensureUserLocation({bool shouldFetchSummary = false}) async {
    
//     // 1. If already set, we're good (just ensure a summary calculation if requested)
//     if (_userLatitude != null && _userLongitude != null) {
//       if (shouldFetchSummary) {
//         await _fetchOrderSummary();
//       }
//       return true;
//     }

//     // 2. If using saved address, try to obtain coords from it
//     if (_useSavedAddress && _selectedAddress != null) {
//       try {
//         final dyn = _selectedAddress as dynamic;
//         final lat = dyn.latitude;
//         final lon = dyn.longitude;
//         if (lat != null && lon != null) {
//           _userLatitude = (lat as num).toDouble();
//           _userLongitude = (lon as num).toDouble();
//           if (shouldFetchSummary) {
//             await _fetchOrderSummary();
//           }
//           return true;
//         }
//       } catch (_) {
//         // Address does not expose latitude/longitude props
//       }

//       // Try forward geocoding using the address string
//       final String combined =
//           '${_selectedAddress!.fullAddress}, ${_selectedAddress!.city ?? ''}, ${_selectedAddress!.country ?? ''}';
//       try {
//         final List<Location> locations = await locationFromAddress(combined);
//         if (locations.isNotEmpty) {
//           _userLatitude = locations.first.latitude;
//           _userLongitude = locations.first.longitude;
//           if (shouldFetchSummary) {
//             await _fetchOrderSummary();
//           }
//           return true;
//         }
//       } catch (e) {
//         print('Forward geocoding failed for saved address: $e');
//       }
//     }

//     // 3. If not using saved address, try building address from controllers and forward geocode
//     final String builtAddress = '${_addressController.text}, ${_cityController.text}, ${_countryController.text}';
//     if (builtAddress.trim().isNotEmpty) {
//       try {
//         final List<Location> locations = await locationFromAddress(builtAddress);
//         if (locations.isNotEmpty) {
//           _userLatitude = locations.first.latitude;
//           _userLongitude = locations.first.longitude;
//           if (shouldFetchSummary) {
//             await _fetchOrderSummary();
//           }
//           return true;
//         }
//       } catch (e) {
//         print('Forward geocoding failed for built address: $e');
//       }
//     }

//     // 4. No coordinates could be determined
//     return false;
//   }

//   Future<void> _placeOrder() async {
//     // ADDRESS VALIDATION CHECK
//     if (!_addressSelectedOrFetched) {
//       _showSnackBar(
//           'Please select your address by clicking one of the location buttons.');
//       return;
//     }

//     if (_selectedPaymentMethod == null) {
//       _showSnackBar('Please select a payment method.');
//       return;
//     }

//     // Must have a calculated summary before proceeding
//     if (!_isSummaryCalculated || _fullOrderSummary == null) {
//       _showSnackBar('Please wait for the delivery fee to be calculated or choose an address.');
//       return;
//     }

//     // Ensure we have user coordinates to send to backend
//     setState(() => _isLoading = true);
//     // Note: ensureUserLocation is called *before* this from address selection, 
//     // but running it again ensures maximum safety for final submission.
//     final bool hasCoords = await _ensureUserLocation(); 
//     if (!hasCoords) {
//       setState(() => _isLoading = false);
//       _showSnackBar('Failed to determine delivery coordinates. Please try fetching location again or choose a saved address with coordinates.');
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _successMessage = null;
//     });

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? token = prefs.getString('jwt_token');
//       if (token == null) {
//         setState(() =>
//             _errorMessage = 'Authentication token not found. Please log in again.');
//         return;
//       }

//       final cartProvider = Provider.of<CartProvider>(context, listen: false);
//       if (cartProvider.items.isEmpty) {
//         setState(() => _errorMessage = 'Your cart is empty. Cannot place an empty order.');
//         return;
//       }

//       final List<Map<String, dynamic>> orderItems =
//           cartProvider.items.values.map((item) => item.toJson()).toList();

//       final missingVendor = orderItems.any((i) => i['vendor'] == null);
//       if (missingVendor) {
//         setState(() => _errorMessage =
//             'One or more items are missing vendor info. Please contact support.');
//         return;
//       }

//       // ⚠️ MODIFICATION 3: Use the backend-calculated total
//       final FullOrderSummary summary = _fullOrderSummary!;
//       final double totalPrice = summary.totalPrice; 

//       // WALLET BALANCE CHECK
//       if (_selectedPaymentMethod == 'Wallet Balance') {
//         if (_walletBalance < totalPrice) {
//           setState(() => _errorMessage =
//               'Insufficient wallet balance (₦${_walletBalance.toStringAsFixed(2)}). Total is ₦${totalPrice.toStringAsFixed(2)}. Please choose another payment method or top up.');
//           return;
//         }
//       }

//       // Prepare request body using backend summary data
//       final Map<String, dynamic> requestBody = {
//         'orderItems': orderItems,
//         'shippingAddress': _useSavedAddress
//             ? _selectedAddress!.toJson()
//             : {
//                 'address': _addressController.text.trim(),
//                 'city': _cityController.text.trim(),
//                 'postalCode': _postalCodeController.text.trim(),
//                 'country': _countryController.text.trim(),
//               },
//         'paymentMethod': _selectedPaymentMethod,
//         // ⚠️ MODIFICATION 4: Use backend-calculated fees
//         'totalShippingPrice': summary.totalShippingPrice,
//         'totalPlatformFees': summary.totalPlatformFees,
//         'taxPrice': summary.taxPrice,
//         'totalPrice': totalPrice, // This is the user-facing total
//         'userLocation': {
//           'latitude': _userLatitude,
//           'longitude': _userLongitude,
//         },
//         'shipmentSummaries':summary.shipmentSummaries.map((s) => s.toJson()).toList(),
//       };

//       // 1) Create order
//       final createOrderUrl = Uri.parse('$baseUrl/api/orders');
//       final createOrderResp = await http.post(
//         createOrderUrl,
//         headers: {
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Bearer $token'
//         },
//         body: jsonEncode(requestBody),
//       );

//       final Map<String, dynamic> createOrderData = _safeJson(createOrderResp.body);

//       if (createOrderResp.statusCode != 201) {
//         setState(() =>
//             _errorMessage = createOrderData['message'] ?? 'Failed to place order.');
//         return;
//       }

//       final String orderId = createOrderData['_id'];
//       print('✅ Order successfully created with ID: $orderId');

//       // --- PAYMENT HANDLING ---
//       if (_selectedPaymentMethod == 'Wallet Balance') {
//         // Process wallet payment directly with the backend
//         final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet');
//         final payResp = await http.put(
//           payUrl,
//           headers: {
//             'Content-Type': 'application/json; charset=UTF-8',
//             'Authorization': 'Bearer $token'
//           },
//         );

//         if (payResp.statusCode == 200) {
//           setState(() =>
//               _successMessage = 'Order placed successfully using Wallet Balance!');
//           cartProvider.clearCart();
//           // Re-fetch wallet balance after successful deduction
//           await _fetchAddressesAndWallet();
//           _showSnackBar(_successMessage!);
//           widget.onOrderSuccess();
//           if (mounted) {
//             Navigator.of(context).popUntil((route) => route.isFirst);
//           }
//           print('✅ Wallet payment successful. Status 200.');
//         } else {
//           final payData = _safeJson(payResp.body);
//           setState(() {
//             _errorMessage = payData['message'] ??
//                 'Order placed, but wallet payment failed. Please contact support.';
//           });
//           print(
//               '🛑 Wallet payment failed. Status ${payResp.statusCode}. Message: ${_errorMessage}');
//         }
//       } else {
//         // EXISTING LOGIC: Handle Card/Bank Transfer via Flutterwave
//         final userEmail = prefs.getString('email') ?? 'customer@example.com';
//         final fullName = prefs.getString('fullName') ?? 'Test User';
//         final phone = prefs.getString('phoneNumber') ?? '08012345678';

//         final paymentService = PaymentService();
//         final ChargeResponse? chargeResponse =
//             await paymentService.startFlutterwavePayment(
//           context: context,
//           amount: totalPrice, // Use the final total price
//           email: userEmail,
//           name: fullName,
//           phoneNumber: phone,
//         );

//         if (chargeResponse == null) {
//           setState(() => _errorMessage = 'Payment was not initiated.');
//           print('🛑 Payment NOT initiated (chargeResponse is null)');
//           return;
//         }

//         final String fwStatus = (chargeResponse.status ?? '').toLowerCase();
//         print('ℹ️ Flutterwave SDK Status: $fwStatus');

//         if (fwStatus == 'cancelled') {
//           setState(() {
//             _errorMessage = 'Payment was explicitly cancelled by the user.';
//           });
//           print('🛑 Payment explicitly cancelled by user.');
//           return;
//         }

//         // 3) Mark order paid on your backend
//         final String? paymentId =
//             chargeResponse.transactionId ?? chargeResponse.txRef;

//         if (paymentId == null) {
//           setState(() => _errorMessage =
//               'Payment failed: Missing transaction reference for verification.');
//           print('🛑 Payment failed: Missing transaction reference.');
//           return;
//         }

//         print('➡️ Proceeding to backend verification with ID: $paymentId');

//         final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
//         final payResp = await http.put(
//           payUrl,
//           headers: {
//             'Content-Type': 'application/json; charset=UTF-8',
//             'Authorization': 'Bearer $token'
//           },
//           body: jsonEncode({
//             'transaction_id': paymentId,
//             'status': chargeResponse.status,
//             'update_time': DateTime.now().toIso8601String(),
//             'email_address': userEmail,
//           }),
//         );

//         if (payResp.statusCode == 200) {
//           setState(
//               () => _successMessage = 'Order placed and paid successfully!');
//           cartProvider.clearCart();
//           _showSnackBar(_successMessage!);
//           widget.onOrderSuccess();
//           if (mounted) {
//             Navigator.of(context).popUntil((route) => route.isFirst);
//           }
//           print('✅ Backend confirmation successful. Status 200.');
//         } else {
//           final payData = _safeJson(payResp.body);
//           setState(() {
//             _errorMessage = payData['message'] ??
//                 'Order placed, but payment confirmation failed. Please contact support.';
//           });
//           print(
//               '🛑 Backend confirmation failed. Status ${payResp.statusCode}. Message: ${_errorMessage}');
//         }
//       } // End of non-wallet payment logic

//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An error occurred: $e. Check backend server and network.';
//       });
//       print('❌ Order placement catch error: $e');
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }


// // =========================================================================
// // BATCH B: Build Method and Widgets
// // =========================================================================

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context);

//     // ⚠️ MODIFICATION 5 (from BATCH B): Use the fetched summary
//     final FullOrderSummary? currentSummary = _fullOrderSummary;

//     return Scaffold(
//       backgroundColor: whiteBackground,
//       appBar: AppBar(
//         title: const Text('Checkout', style: TextStyle(color: greenYellow)),
//         backgroundColor: deepNavyBlue,
//         elevation: 1,
//         iconTheme: const IconThemeData(color: greenYellow),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const Text(
//                 'Shipping Address',
//                 style: TextStyle(
//                     color: deepNavyBlue,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),

//               // Address selection buttons
//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: () {
//                         // This now triggers location fetch and then _fetchOrderSummary
//                         _fetchCurrentLocation();
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: !_useSavedAddress &&
//                                 _addressSelectedOrFetched
//                             ? deepNavyBlue
//                             : deepNavyBlue.withOpacity(0.1),
//                         foregroundColor: !_useSavedAddress &&
//                                 _addressSelectedOrFetched
//                             ? greenYellow
//                             : deepNavyBlue,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                       icon: const Icon(Icons.my_location),
//                       label: const Text('Use Current Location'),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: () async {
//                         // Clear manual fields when selecting saved address
//                         _addressController.clear();
//                         _cityController.clear();
//                         _postalCodeController.clear();
//                         _countryController.clear();

//                         final selectedAddress =
//                             await _showAddressSelectionDialog();
                        
//                         // ⚠️ MODIFICATION 6 (from BATCH B): Handle selection and fetch summary
//                         if (selectedAddress != null) {
//                           setState(() {
//                             _selectedAddress = selectedAddress;
//                             _useSavedAddress = true;
//                             _addressSelectedOrFetched = true;
//                           });
                          
//                           // This ensures coordinates are determined (geocoding if necessary) and summary is fetched
//                           await _ensureUserLocation(shouldFetchSummary: true); 

//                         } else {
//                           // If user cancels dialog or no address, keep the current state unless one was previously selected.
//                           setState(() {
//                             if (_selectedAddress == null) {
//                               _useSavedAddress = false;
//                               _addressSelectedOrFetched = false;
//                               _isSummaryCalculated = false;
//                               _fullOrderSummary = null;
//                             }
//                           });
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _useSavedAddress && _selectedAddress != null
//                             ? deepNavyBlue
//                             : deepNavyBlue.withOpacity(0.1),
//                         foregroundColor: _useSavedAddress && _selectedAddress != null
//                             ? greenYellow
//                             : deepNavyBlue,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                       icon: const Icon(Icons.location_on),
//                       label: const Text('Saved Address'),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),

//               // Conditional display of address input fields or selected address
//               if (_addressSelectedOrFetched &&
//                   _useSavedAddress &&
//                   _selectedAddress != null)
//                 Card(
//                   elevation: 4,
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   color: deepNavyBlue,
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Selected Address:',
//                             style: TextStyle(
//                                 color: greenYellow.withOpacity(0.7),
//                                 fontSize: 16)),
//                         const SizedBox(height: 5),
//                         Text(_selectedAddress!.fullAddress,
//                             style: const TextStyle(
//                                 fontSize: 18, color: whiteBackground)),
//                         Text(
//                             '${_selectedAddress!.city}, ${_selectedAddress!.postalCode}, ${_selectedAddress!.country}',
//                             style: const TextStyle(
//                                 fontSize: 16, color: whiteBackground)),
//                       ],
//                     ),
//                   ),
//                 )
//               else
//                 Column(
//                   children: [
//                     Text(
//                       _addressSelectedOrFetched
//                           ? 'Location Ready for Order'
//                           : 'Please use a button above to set the delivery address.',
//                       style: TextStyle(
//                         color: _addressSelectedOrFetched
//                             ? deepNavyBlue
//                             : Colors.red,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 15),
//                     // Display current/fetched location (disabled fields)
//                     TextFormField(
//                       controller: _addressController,
//                       decoration: _inputDecoration('Address'),
//                       enabled: false, // User must use buttons
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _cityController,
//                       decoration: _inputDecoration('City'),
//                       enabled: false, // User must use buttons
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _postalCodeController,
//                       decoration: _inputDecoration('Postal Code'),
//                       enabled: false, // User must use buttons
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _countryController,
//                       decoration: _inputDecoration('Country'),
//                       enabled: false, // User must use buttons
//                     ),
//                   ],
//                 ),
//               const SizedBox(height: 30),

//               const Text(
//                 'Payment Method',
//                 style: TextStyle(
//                     color: deepNavyBlue,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),
//               DropdownButtonFormField<String>(
//                 value: _selectedPaymentMethod,
//                 decoration: _inputDecoration('Select Payment Method').copyWith(
//                   contentPadding:
//                       const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//                 ),
//                 dropdownColor: deepNavyBlue.withOpacity(0.9),
//                 style: const TextStyle(color: greenYellow),
//                 // MODIFIED: Added 'Wallet Balance' option
//                 items: [
//                   'Card',
//                   'Bank Transfer',
//                   // Display wallet balance with current balance
//                   'Wallet Balance (₦${_walletBalance.toStringAsFixed(0)})'
//                 ]
//                     .map((method) => DropdownMenuItem<String>(
//                           value: method.contains('Wallet Balance')
//                               ? 'Wallet Balance'
//                               : method,
//                           child: Text(method),
//                         ))
//                     .toList(),
//                 onChanged: (val) => setState(() => _selectedPaymentMethod = val),
//                 validator: (value) =>
//                     value == null ? 'Please select a payment method' : null,
//               ),
//               const SizedBox(height: 30),

//               const Text(
//                 'Order Summary',
//                 style: TextStyle(
//                     color: deepNavyBlue,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),

//               // ⚠️ MODIFICATION 7 (from BATCH B): Conditional display based on summary status
//               if (_isLoading && !_isSummaryCalculated)
//                 const Center(child: CircularProgressIndicator(color: deepNavyBlue))
//               else if (_isSummaryCalculated && currentSummary != null)
//                 _buildFullSummaryCard(currentSummary, cartProvider)
//               else
//                 const Padding(
//                   padding: EdgeInsets.all(16.0),
//                   child: Text(
//                     'Awaiting delivery address confirmation to calculate final summary.',
//                     style: TextStyle(color: deepNavyBlue),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
              
//               const SizedBox(height: 30),

//               if (_errorMessage != null)
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 15.0),
//                   child: Text(
//                     _errorMessage!,
//                     style: const TextStyle(color: deepNavyBlue, fontSize: 14),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),

//               _isLoading
//                   ? const Center(
//                       child: CircularProgressIndicator(color: deepNavyBlue))
//                   : SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         onPressed: (cartProvider.itemCount > 0 &&
//                                 _addressSelectedOrFetched &&
//                                 _isSummaryCalculated && // Must have calculated summary
//                                 _selectedPaymentMethod != null)
//                             ? _placeOrder
//                             : null,
//                         icon: const Icon(Icons.check_circle, color: deepNavyBlue),
//                         label: const Text('Place Order',
//                             style:
//                                 TextStyle(color: deepNavyBlue, fontSize: 18)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: greenYellow,
//                           padding: const EdgeInsets.symmetric(vertical: 15),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12)),
//                           elevation: 5,
//                         ),
//                       ),
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ⚠️ MODIFICATION 8 (from BATCH B): New Summary Widget for Multi-Vendor Breakdown
//   Widget _buildFullSummaryCard(
//       FullOrderSummary summary, CartProvider cartProvider) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       color: deepNavyBlue,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Individual Vendor Breakdown (if more than one vendor)
//             if (summary.shipmentSummaries.length > 1) ...[
//               Text(
//                 'Breakdown by Vendor:',
//                 style: TextStyle(
//                     color: greenYellow.withOpacity(0.7),
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
//               ...summary.shipmentSummaries.map((shipment) => Padding(
//                     padding: const EdgeInsets.only(bottom: 8.0, left: 10),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '📦 ${shipment.vendorName} Shipment:',
//                           style: const TextStyle(
//                               color: greenYellow,
//                               fontWeight: FontWeight.bold)),
//                         _buildSummaryRow('  - Item Subtotal:',
//                             '₦${shipment.subtotal.toStringAsFixed(2)}'),
//                         _buildSummaryRow('  - Delivery Fee:',
//                             '₦${shipment.shippingPrice.toStringAsFixed(2)}'),
//                         _buildSummaryRow('  - Platform Fee:',
//                             '₦${shipment.platformFee.toStringAsFixed(2)}'),
//                       ],
//                     ),
//                   )).toList(),
//               const Divider(height: 30, thickness: 0.5, color: greenYellow),
//             ],

//             // Consolidated Totals
//             _buildSummaryRow(
//                 'Total Items Subtotal (${cartProvider.itemCount} items):',
//                 '₦${summary.totalSubtotal.toStringAsFixed(2)}'),
//             _buildSummaryRow('Total Delivery Fees:',
//                 '₦${summary.totalShippingPrice.toStringAsFixed(2)}'),
//             // _buildSummaryRow('Platform Fee:',
//             //     '₦${summary.totalPlatformFees.toStringAsFixed(2)}'),
//             // Added Tax (if applicable)
//             if (summary.taxPrice > 0)
//               _buildSummaryRow(
//                   'Tax Price:', '₦${summary.taxPrice.toStringAsFixed(2)}'),

//             const Divider(height: 30, thickness: 1, color: greenYellow),

//             // Final Total
//             _buildTotalRow(
//                 'Grand Total:', '₦${summary.totalPrice.toStringAsFixed(2)}'),
//           ],
//         ),
//       ),
//     );
//   }


//   Widget _buildSummaryRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label,
//               style: const TextStyle(fontSize: 16, color: whiteBackground)),
//           Text(value,
//               style: const TextStyle(fontSize: 16, color: whiteBackground)),
//         ],
//       ),
//     );
//   }

//   Widget _buildTotalRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label,
//               style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: whiteBackground)),
//           Text(value,
//               style: const TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   color: greenYellow)),
//         ],
//       ),
//     );
//   }

//   InputDecoration _inputDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       labelStyle: const TextStyle(color: deepNavyBlue),
//       filled: true,
//       fillColor: deepNavyBlue.withOpacity(0.1),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10.0),
//         borderSide: BorderSide.none,
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10.0),
//         borderSide: const BorderSide(color: deepNavyBlue, width: 2),
//       ),
//     );
//   }

//   // A dialog to let the user select a saved address
//   Future<Address?> _showAddressSelectionDialog() async {
//     if (_userAddresses.isEmpty) {
//       _showSnackBar('You have no saved addresses. Add one from your profile.');
//       return null;
//     }
//     return showDialog<Address>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Select a Delivery Address'),
//           content: SizedBox(
//             width: double.maxFinite,
//             child: ListView.builder(
//               shrinkWrap: true,
//               itemCount: _userAddresses.length,
//               itemBuilder: (context, index) {
//                 final address = _userAddresses[index];
//                 return ListTile(
//                   title: Text(address.fullAddress),
//                   subtitle: Text('${address.city}, ${address.country}'),
//                   onTap: () {
//                     Navigator.of(context).pop(address);
//                   },
//                 );
//               },
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(null);
//               },
//               child: const Text('Cancel'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Map<String, dynamic> _safeJson(String body) {
//     try {
//       return jsonDecode(body) as Map<String, dynamic>;

//     } catch (_) {
//       // In case of non-JSON response (e.g., server error with plain text)
//       print('Warning: Failed to decode JSON body: $body');
//       return {};
//     }
//   }
// }