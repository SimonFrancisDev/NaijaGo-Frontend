import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for timeouts

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
// Backend-driven Order Summary Models
// =========================================================================

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
      vendorName: json['vendorName'] as String? ?? 'Unknown Vendor',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingPrice: (json['shippingPrice'] as num?)?.toDouble() ?? 0.0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      vendorId: json['vendorId'] as String? ?? '',
      vendorLatitude: (json['vendorLocation']?['latitude'] as num?)?.toDouble() ?? 0.0,
      vendorLongitude: (json['vendorLocation']?['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorName': vendorName,
      'subtotal': subtotal,
      'shippingPrice': shippingPrice,
      'platformFee': platformFee,
      'items': items,
      'vendor': vendorId,
      'vendorLocation': {
        'latitude': vendorLatitude,
        'longitude': vendorLongitude,
      },
    };
  }
}

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
              .toList() ??
          [],
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
  bool _isSummaryLoading = false;
  bool _isPlacingOrder = false; // Prevent double-tap
  bool _isProcessingPayment = false; // Track payment processing

  String? _errorMessage;
  String? _successMessage;

  double? _userLatitude;
  double? _userLongitude;

  FullOrderSummary? _fullOrderSummary;
  bool _isSummaryCalculated = false;

  // Lock to prevent concurrent location fetching
  bool _isFetchingLocation = false;
  // Lock to prevent concurrent summary fetching
  bool _isFetchingSummary = false;

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

  String _formatPriceWithCommas(double price) {
    final formatter = NumberFormat('#,##0.00', 'en_NG');
    return '₦${formatter.format(price)}';
  }

  Future<void> _fetchAddressesAndWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    if (_isLoading) return; // Prevent multiple concurrent calls

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addressesJson = data['deliveryAddresses'] as List<dynamic>? ?? [];
        final wallet = (data['userWalletBalance'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          _userAddresses = addressesJson.map((json) => Address.fromJson(json)).toList();
          _walletBalance = wallet;

          if (_userAddresses.isNotEmpty) {
            _selectedAddress = _userAddresses.firstWhere(
              (addr) => addr.isDefault == true,
              orElse: () => _userAddresses.first,
            );
            _useSavedAddress = true;
            _addressSelectedOrFetched = true;
          }
        });

        await _ensureUserLocation(shouldFetchSummary: true);
      } else {
        _showSnackBar('Failed to load profile');
      }
    } catch (e) {
      _showSnackBar('Network error loading profile');
      print('Profile fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrderSummary() async {
    if (!_addressSelectedOrFetched || _isSummaryLoading || _isFetchingSummary) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) return;

    setState(() {
      _isSummaryLoading = true;
      _isFetchingSummary = true;
      _isSummaryCalculated = false;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _showSnackBar('Authentication token not found.');
      setState(() {
        _isSummaryLoading = false;
        _isFetchingSummary = false;
      });
      return;
    }

    try {
      final orderItems = cartProvider.items.values.map((item) => item.toJson()).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/summary'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
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
      ).timeout(const Duration(seconds: 20));

      final responseData = _safeJson(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _fullOrderSummary = FullOrderSummary.fromJson(responseData);
          _isSummaryCalculated = true;
        });
        print('✅ Summary fetched: Total ₦${_fullOrderSummary?.totalPrice ?? 0}');
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to calculate delivery fees';
        });
        print('Summary fetch failed: ${response.statusCode} - $_errorMessage');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error calculating fees: $e');
      print('Summary fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSummaryLoading = false;
          _isFetchingSummary = false;
        });
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return; // Prevent concurrent location fetching
    
    setState(() {
      _isFetchingLocation = true;
      _isLoading = true;
    });
    
    try {
      setState(() {
        _useSavedAddress = false;
        _selectedAddress = null;
        _addressSelectedOrFetched = false;
        _isSummaryCalculated = false;
        _fullOrderSummary = null;
      });

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) throw Exception('No address found');

      final place = placemarks.first;

      _addressController.text = '${place.street ?? ''}, ${place.subLocality ?? ''}';
      _cityController.text = place.locality ?? '';
      _postalCodeController.text = place.postalCode ?? '';
      _countryController.text = place.country ?? '';

      setState(() {
        _addressSelectedOrFetched = true;
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });

      _showSnackBar('Location fetched successfully! Calculating delivery fee...');
      await _fetchOrderSummary();
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      print('Current location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _ensureUserLocation({bool shouldFetchSummary = false}) async {
    if (_userLatitude != null && _userLongitude != null) {
      if (shouldFetchSummary && !_isFetchingSummary) {
        await _fetchOrderSummary();
      }
      return true;
    }

    if (_useSavedAddress && _selectedAddress != null) {
      try {
        final addressStr = '${_selectedAddress!.fullAddress}, ${_selectedAddress!.city ?? ''}, ${_selectedAddress!.country ?? ''}';
        final locations = await locationFromAddress(addressStr).timeout(const Duration(seconds: 10));
        if (locations.isNotEmpty) {
          setState(() {
            _userLatitude = locations.first.latitude;
            _userLongitude = locations.first.longitude;
          });
          if (shouldFetchSummary && !_isFetchingSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        print('Saved address geocoding failed: $e');
      }
    }

    final builtAddress = '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_countryController.text.trim()}';
    if (builtAddress.trim().isNotEmpty) {
      try {
        final locations = await locationFromAddress(builtAddress).timeout(const Duration(seconds: 10));
        if (locations.isNotEmpty) {
          setState(() {
            _userLatitude = locations.first.latitude;
            _userLongitude = locations.first.longitude;
          });
          if (shouldFetchSummary && !_isFetchingSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        print('Manual address geocoding failed: $e');
      }
    }

    return false;
  }

  // Helper method to get processor message from ChargeResponse
  // Fixed: ChargeResponse in flutterwave_standard 1.1.0 doesn't have 'message' property
  String? _getProcessorMessage(ChargeResponse response) {
    // First check if response has any error property
    // Print the response structure to see what's available
    print('ChargeResponse structure: ${response.toJson()}');
    
    // Based on typical Flutterwave response, check common properties
    // Try to get the transaction reference or status
    if (response.txRef != null && response.txRef!.isNotEmpty) {
      return 'Transaction Ref: ${response.txRef}';
    }
    if (response.transactionId != null && response.transactionId!.isNotEmpty) {
      return 'Transaction ID: ${response.transactionId}';
    }
    
    // The status property should always be available
    return 'Status: ${response.status}';
  }

  // Validate all conditions before allowing order placement
  bool _validateOrderPlacement() {
    if (_isLoading || _isPlacingOrder || _isProcessingPayment) {
      return false;
    }
    
    if (!_addressSelectedOrFetched) {
      _showSnackBar('Please select your address', isError: true);
      return false;
    }

    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method', isError: true);
      return false;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      _showSnackBar('Your cart is empty', isError: true);
      return false;
    }

    if (!_isSummaryCalculated || _fullOrderSummary == null) {
      _showSnackBar('Please wait for delivery fee calculation', isError: true);
      return false;
    }

    // if (_selectedPaymentMethod == 'Wallet Balance' && _walletBalance < _fullOrderSummary!.totalPrice) {
    //   _showSnackBar('Insufficient wallet balance', isError: true);
    //   return false;
    // }

    // FIX: Check for 'Wallet' not 'Wallet Balance'
      if (_selectedPaymentMethod == 'Wallet' && _walletBalance < _fullOrderSummary!.totalPrice) {
        _showSnackBar('Insufficient wallet balance', isError: true);
        return false;
      }

    return true;
  }

  Future<void> _placeOrder() async {
    // Prevent any concurrent order placement
    if (!_validateOrderPlacement()) {
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _isProcessingPayment = true;
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Ensure coordinates are available
      final hasCoords = await _ensureUserLocation();
      if (!hasCoords) {
        throw Exception('Failed to determine delivery coordinates');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Authentication token not found');

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final orderItems = cartProvider.items.values.map((item) => item.toJson()).toList();

      if (orderItems.any((i) => i['vendor'] == null)) {
        throw Exception('Missing vendor info in cart');
      }

      final summary = _fullOrderSummary!;
      final totalPrice = summary.totalPrice;

      final requestBody = {
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

      // Create the order first
      final createOrderUrl = Uri.parse('$baseUrl/api/orders');
      final createOrderResp = await http.post(
        createOrderUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      final createOrderData = _safeJson(createOrderResp.body);

      if (createOrderResp.statusCode != 201) {
        _errorMessage = createOrderData['message'] ?? 'Failed to place order';
        _showSnackBar(_errorMessage!, isError: true);
        return;
      }

      final orderId = createOrderData['_id'] as String?;
      if (orderId == null) throw Exception('No order ID received');

      // Handle payment based on selected method
      if (_selectedPaymentMethod == 'Wallet') {
        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
        );

        if (payResp.statusCode == 200) {
          _successMessage = 'Order placed using Wallet!';
          cartProvider.clearCart();
          await _fetchAddressesAndWallet();
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          _errorMessage = payData['message'] ?? 'Wallet payment failed';
          _showSnackBar(_errorMessage!, isError: true);
        }
      } else {
        // External payment (Flutterwave)
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
          _errorMessage = 'Payment not initiated or cancelled';
          _showSnackBar(_errorMessage!, isError: true);
          return;
        }

        final fwStatus = (chargeResponse.status ?? '').toLowerCase();

        if (fwStatus == 'cancelled') {
          _errorMessage = 'Payment cancelled by user';
          _showSnackBar(_errorMessage!);
          return;
        }

        if (fwStatus != 'success') {
          // Use the fixed helper method
          final processorMsg = _getProcessorMessage(chargeResponse);
          _errorMessage = 'Payment failed: $processorMsg';
          _showSnackBar(_errorMessage!, isError: true);
          print('Flutterwave failure: $processorMsg | Full response: ${chargeResponse.toJson()}');
          return;
        }

        // Use txRef (preferred) or fallback to transactionId
        final paymentRef = chargeResponse.txRef ?? chargeResponse.transactionId;

        if (paymentRef == null || paymentRef.isEmpty) {
          _errorMessage = 'Missing transaction reference';
          _showSnackBar(_errorMessage!, isError: true);
          return;
        }

        // Confirm payment with backend
        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'transaction_id': paymentRef,
            'status': chargeResponse.status,
            'update_time': DateTime.now().toIso8601String(),
            'email_address': userEmail,
          }),
        );

        if (payResp.statusCode == 200) {
          _successMessage = 'Order placed and paid!';
          cartProvider.clearCart();
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          _errorMessage = payData['message'] ?? 'Payment confirmation failed';
          _showSnackBar(_errorMessage!, isError: true);
          print('Backend confirmation failed: ${payResp.statusCode} - ${payResp.body}');
        }
      }
    } catch (e, stack) {
      _errorMessage = 'Error: $e';
      _showSnackBar('Failed to place order. Try again.', isError: true);
      print('Place order error: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlacingOrder = false;
          _isProcessingPayment = false;
        });
      }
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
                      onPressed: (_isLoading || _isFetchingLocation) ? null : _fetchCurrentLocation,
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
                      onPressed: (_isLoading || _isFetchingLocation)
                          ? null
                          : () async {
                              _addressController.clear();
                              _cityController.clear();
                              _postalCodeController.clear();
                              _countryController.clear();

                              final selected = await _showAddressSelectionDialog();
                              if (selected != null && mounted) {
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
                        Text('${_selectedAddress!.city ?? ''}, ${_selectedAddress!.postalCode ?? ''}, ${_selectedAddress!.country ?? ''}',
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

              // DropdownButtonFormField<String>(
              //   value: _selectedPaymentMethod,
              //   decoration: _inputDecoration('Select Payment Method').copyWith(
              //     contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              //   ),
              //   dropdownColor: deepNavyBlue.withOpacity(0.9),
              //   style: const TextStyle(color: greenYellow),
              //   items: [
              //     'Card',
              //     'Bank Transfer',
              //     'Wallet Balance (${_formatPriceWithCommas(_walletBalance)})'
              //   ].map((method) => DropdownMenuItem<String>(
              //         value: method.contains('Wallet Balance') ? 'Wallet Balance' : method,
              //         child: Text(method),
              //       )).toList(),
              //   onChanged: (_isLoading || _isPlacingOrder || _isProcessingPayment) 
              //       ? null 
              //       : (val) => setState(() => _selectedPaymentMethod = val),
              //   validator: (value) => value == null ? 'Select payment method' : null,
              // ),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: _inputDecoration('Select Payment Method').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                ),
                dropdownColor: deepNavyBlue.withOpacity(0.9),
                style: const TextStyle(color: greenYellow),
                items: [
                  // FIX: Use explicit DropdownMenuItem with correct values
                  const DropdownMenuItem<String>(
                    value: 'Card',  // Must match backend exactly
                    child: Text('Card'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'Bank Transfer',  // Must match backend exactly
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem<String>(
                    // CRITICAL: Send 'Wallet' not 'Wallet Balance'
                    value: 'Wallet',
                    child: Text('Wallet Balance (${_formatPriceWithCommas(_walletBalance)})'),
                  ),
                ],
                onChanged: (_isLoading || _isPlacingOrder || _isProcessingPayment) 
                    ? null 
                    : (val) => setState(() => _selectedPaymentMethod = val),
                validator: (value) => value == null ? 'Select payment method' : null,
              ),
              const SizedBox(height: 30),

              const Text('Order Summary', style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              if (_isSummaryLoading)
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
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),

              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),

              _isLoading || _isPlacingOrder || _isProcessingPayment
                  ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading ||
                                _isPlacingOrder ||
                                _isProcessingPayment ||
                                cartProvider.itemCount == 0 ||
                                !_addressSelectedOrFetched ||
                                !_isSummaryCalculated ||
                                _selectedPaymentMethod == null)
                            ? null
                            : _placeOrder,
                        icon: const Icon(Icons.check_circle, color: deepNavyBlue),
                        label: Text(
                          (_isPlacingOrder || _isProcessingPayment) ? 'Processing...' : 'Place Order',
                          style: const TextStyle(color: deepNavyBlue, fontSize: 18),
                        ),
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
                        _buildSummaryRow('  - Item Subtotal:', _formatPriceWithCommas(shipment.subtotal)),
                        _buildSummaryRow('  - Delivery Fee:', _formatPriceWithCommas(shipment.shippingPrice)),
                      ],
                    ),
                  )),
              const Divider(height: 30, thickness: 0.5, color: greenYellow),
            ],
            _buildSummaryRow('Total Items Subtotal (${cartProvider.itemCount} items):', _formatPriceWithCommas(summary.totalSubtotal)),
            _buildSummaryRow('Total Delivery Fees:', _formatPriceWithCommas(summary.totalShippingPrice)),
            if (summary.taxPrice > 0) _buildSummaryRow('Tax Price:', _formatPriceWithCommas(summary.taxPrice)),
            const Divider(height: 30, thickness: 1, color: greenYellow),
            _buildTotalRow('Grand Total:', _formatPriceWithCommas(summary.totalPrice)),
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
                subtitle: Text('${address.city ?? ''}, ${address.country ?? ''}'),
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