// // lib/screens/Main/checkout_screen.dart
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
//   bool _useSavedAddress = false;
//   Address? _selectedAddress;
//   List<Address> _userAddresses = [];

//   // Payment method selection
//   String? _selectedPaymentMethod = 'Card'; // Default to 'Card'

//   bool _isLoading = false;
//   String? _errorMessage;
//   String? _successMessage;

//   @override
//   void initState() {
//     super.initState();
//     _fetchAddresses();
//   }

//   @override
//   void dispose() {
//     _addressController.dispose();
//     _cityController.dispose();
//     _postalCodeController.dispose();
//     _countryController.dispose();
//     super.dispose();
//   }

//   // Treat both "successful" and "success" as success (Flutterwave sometimes returns either)
//   bool _isFwSuccess(String? status) {
//     if (status == null) return false;
//     final s = status.toLowerCase().trim();
//     return s == 'successful' || s == 'success';
//   }

//   Future<void> _fetchAddresses() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     if (token == null) {
//       // Handle case where user is not logged in
//       return;
//     }

//     try {
//       final Uri url = Uri.parse('$baseUrl/api/auth/me');
//       final response = await http.get(
//         url,
//         headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         final List<dynamic> addressesJson = responseData['deliveryAddresses'] ?? [];
//         setState(() {
//           _userAddresses = addressesJson.map((json) => Address.fromJson(json)).toList();
//           // Optionally pre-select the default address
//           if (_userAddresses.isNotEmpty) {
//             _selectedAddress = _userAddresses.firstWhere(
//                 (addr) => addr.isDefault,
//                 orElse: () => _userAddresses.first,
//             );
//           }
//         });
//       }
//     } catch (e) {
//       print('Error fetching user addresses: $e');
//     }
//   }

//   Future<void> _fetchCurrentLocation() async {
//     setState(() => _isLoading = true);
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

//       Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//       List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
//       Placemark place = placemarks.first;

//       _addressController.text = '${place.street}, ${place.subLocality}';
//       _cityController.text = place.locality ?? '';
//       _postalCodeController.text = place.postalCode ?? '';
//       _countryController.text = place.country ?? '';
//       _showSnackBar('Location fetched successfully!');
//     } catch (e) {
//       _showSnackBar('Failed to get current location: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//     }
//   }

//   Future<void> _placeOrder() async {
//     // If using manual entry, validate the form
//     if (!_useSavedAddress && !_formKey.currentState!.validate()) return;
//     if (_selectedPaymentMethod == null) {
//       _showSnackBar('Please select a payment method.');
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
//         setState(() => _errorMessage = 'Authentication token not found. Please log in again.');
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
//         setState(() => _errorMessage = 'One or more items are missing vendor info. Please contact support.');
//         return;
//       }

//       // Calculate fees based on the latest business logic
//       double shippingPrice = 0.0;
//       final shippingCity = (_useSavedAddress ? _selectedAddress?.city : _cityController.text.trim())?.toLowerCase();

//       if (shippingCity != null) {
//         if (shippingCity.contains('gwarinpa')) {
//           shippingPrice = 2000.00;
//         } else if (shippingCity.contains('abuja')) {
//           shippingPrice = 5000.00;
//         }
//       }

//       final double subtotal = cartProvider.totalAmount;
//       final double serviceFee = subtotal * 0.15;
//       final double totalPrice = subtotal + serviceFee + shippingPrice;

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
//         'paymentMethod': _selectedPaymentMethod, // CORRECTED HERE
//         'serviceFee': serviceFee,
//         'shippingPrice': shippingPrice,
//         'totalPrice': totalPrice,
//       };

//       // 1) Create order
//       final createOrderUrl = Uri.parse('$baseUrl/api/orders');
//       final createOrderResp = await http.post(
//         createOrderUrl,
//         headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
//         body: jsonEncode(requestBody), // THIS LINE WAS MISSING THE REQUEST BODY
//       );

//       final Map<String, dynamic> createOrderData = _safeJson(createOrderResp.body);

//       if (createOrderResp.statusCode != 201) {
//         setState(() => _errorMessage = createOrderData['message'] ?? 'Failed to place order.');
//         return;
//       }

//       final String orderId = createOrderData['_id'];

//       // 2) Launch Flutterwave via PaymentService
//       final userEmail = prefs.getString('email') ?? 'customer@example.com';
//       final fullName = prefs.getString('fullName') ?? 'Test User';
//       final phone = prefs.getString('phoneNumber') ?? '08012345678';

//       final paymentService = PaymentService();
//       final ChargeResponse? chargeResponse = await paymentService.startFlutterwavePayment(
//         context: context,
//         amount: totalPrice,
//         email: userEmail,
//         name: fullName,
//         phoneNumber: phone,
//       );

//       if (chargeResponse == null) {
//         setState(() => _errorMessage = 'Payment was not initiated.');
//         return;
//       }

//       if (!_isFwSuccess(chargeResponse.status)) {
//         setState(() {
//           final s = (chargeResponse.status ?? '').toLowerCase();
//           _errorMessage = s == 'cancelled' ? 'Payment was cancelled.' : 'Payment failed. Please try again.';
//         });
//         return;
//       }

//       // 3) Mark order paid on your backend
//       final String paymentId = chargeResponse.transactionId ?? chargeResponse.txRef ?? 'flw_${DateTime.now().millisecondsSinceEpoch}';

//       final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
//       final payResp = await http.put(
//         payUrl,
//         headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
//         body: jsonEncode({
//           'id': paymentId,
//           'status': chargeResponse.status,
//           'update_time': DateTime.now().toIso8601String(),
//           'email_address': userEmail,
//         }),
//       );

//       if (payResp.statusCode == 200) {
//         setState(() => _successMessage = 'Order placed and paid successfully!');
//         cartProvider.clearCart();
//         _showSnackBar(_successMessage!);
//         widget.onOrderSuccess();
//         if (mounted) {
//           Navigator.of(context).popUntil((route) => route.isFirst);
//         }
//       } else {
//         final payData = _safeJson(payResp.body);
//         setState(() {
//           _errorMessage = payData['message'] ?? 'Order placed, but payment confirmation failed. Please contact support.';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An error occurred: $e. Check backend server and network.';
//       });
//       print('Order placement error: $e');
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context);

//     // Calculate fees for the order summary display
//     final double subtotal = cartProvider.totalAmount;
//     final double serviceFee = subtotal * 0.15;
//     double shippingPrice = 0.0;
//     final shippingCity = (_useSavedAddress ? _selectedAddress?.city : _cityController.text.trim())?.toLowerCase();

//     if (shippingCity != null) {
//       if (shippingCity.contains('gwarinpa')) {
//         shippingPrice = 2000.00;
//       } else if (shippingCity.contains('abuja')) {
//         shippingPrice = 5000.00;
//       }
//     }

//     final double totalPrice = subtotal + serviceFee + shippingPrice;

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
//                 style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),

//               // Address selection buttons
//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: () {
//                         setState(() {
//                           _useSavedAddress = false;
//                         });
//                         _fetchCurrentLocation();
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _useSavedAddress ? deepNavyBlue.withOpacity(0.1) : deepNavyBlue,
//                         foregroundColor: _useSavedAddress ? deepNavyBlue : greenYellow,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
//                         setState(() {
//                           _useSavedAddress = true;
//                           _addressController.clear();
//                           _cityController.clear();
//                           _postalCodeController.clear();
//                           _countryController.clear();
//                         });
//                         final selectedAddress = await _showAddressSelectionDialog();
//                         if (selectedAddress != null) {
//                           setState(() {
//                             _selectedAddress = selectedAddress;
//                           });
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _useSavedAddress ? deepNavyBlue : deepNavyBlue.withOpacity(0.1),
//                         foregroundColor: _useSavedAddress ? greenYellow : deepNavyBlue,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
//               if (_useSavedAddress && _selectedAddress != null)
//                 Card(
//                   elevation: 4,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   color: deepNavyBlue,
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Selected Address:', style: TextStyle(color: greenYellow.withOpacity(0.7), fontSize: 16)),
//                         const SizedBox(height: 5),
//                         Text(_selectedAddress!.fullAddress, style: const TextStyle(fontSize: 18, color: whiteBackground)),
//                         Text('${_selectedAddress!.city}, ${_selectedAddress!.postalCode}, ${_selectedAddress!.country}',
//                             style: const TextStyle(fontSize: 16, color: whiteBackground)),
//                       ],
//                     ),
//                   ),
//                 )
//               else if (_useSavedAddress && _userAddresses.isEmpty)
//                 const Center(
//                   child: Text('No saved addresses found. Please add one or use your current location.',
//                       textAlign: TextAlign.center, style: TextStyle(color: deepNavyBlue)),
//                 )
//               else
//                 Column(
//                   children: [
//                     TextFormField(
//                       controller: _addressController,
//                       decoration: _inputDecoration('Address'),
//                       validator: (value) => value == null || value.isEmpty ? 'Please enter your address' : null,
//                       enabled: !_useSavedAddress,
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _cityController,
//                       decoration: _inputDecoration('City'),
//                       validator: (value) => value == null || value.isEmpty ? 'Please enter your city' : null,
//                       enabled: !_useSavedAddress,
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _postalCodeController,
//                       decoration: _inputDecoration('Postal Code'),
//                       validator: (value) => value == null || value.isEmpty ? 'Please enter your postal code' : null,
//                       enabled: !_useSavedAddress,
//                     ),
//                     const SizedBox(height: 15),
//                     TextFormField(
//                       controller: _countryController,
//                       decoration: _inputDecoration('Country'),
//                       validator: (value) => value == null || value.isEmpty ? 'Please enter your country' : null,
//                       enabled: !_useSavedAddress,
//                     ),
//                   ],
//                 ),
//               const SizedBox(height: 30),

//               const Text(
//                 'Payment Method',
//                 style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),
//               DropdownButtonFormField<String>(
//                 value: _selectedPaymentMethod,
//                 decoration: _inputDecoration('Select Payment Method').copyWith(
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//                 ),
//                 dropdownColor: deepNavyBlue.withOpacity(0.9),
//                 style: const TextStyle(color: greenYellow),
//                 items: ['Card', 'Bank Transfer']
//                     .map((method) => DropdownMenuItem<String>(
//                           value: method,
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
//                 style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 15),
//               Card(
//                 elevation: 4,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 color: deepNavyBlue,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     children: [
//                       _buildSummaryRow('Subtotal (${cartProvider.itemCount} items):', '₦${subtotal.toStringAsFixed(2)}'),
//                       _buildSummaryRow('Shipping:', '₦${shippingPrice.toStringAsFixed(2)}'),
//                       _buildSummaryRow('Service Fee (15%):', '₦${serviceFee.toStringAsFixed(2)}'),
//                       const Divider(height: 30, thickness: 1, color: greenYellow),
//                       _buildTotalRow('Total:', '₦${totalPrice.toStringAsFixed(2)}'),
//                     ],
//                   ),
//                 ),
//               ),
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
//                   ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
//                   : SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         onPressed: (cartProvider.itemCount > 0 && (_useSavedAddress ? _selectedAddress != null : true) && _selectedPaymentMethod != null)
//                             ? _placeOrder
//                             : null,
//                         icon: const Icon(Icons.check_circle, color: deepNavyBlue),
//                         label: const Text('Place Order', style: TextStyle(color: deepNavyBlue, fontSize: 18)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: greenYellow,
//                           padding: const EdgeInsets.symmetric(vertical: 15),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

//   Widget _buildSummaryRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: const TextStyle(fontSize: 16, color: whiteBackground)),
//           Text(value, style: const TextStyle(fontSize: 16, color: whiteBackground)),
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
//           Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: whiteBackground)),
//           Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: greenYellow)),
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
//       return {};
//     }
//   }
// }

// lib/screens/Main/checkout_screen.dart
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

  // New state variables for address selection
  bool _useSavedAddress = false;
  Address? _selectedAddress;
  List<Address> _userAddresses = [];

  // Payment method selection
  String? _selectedPaymentMethod = 'Card'; // Default to 'Card'

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // Treat both "successful" and "success" as success (Flutterwave sometimes returns either)
  bool _isFwSuccess(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return s == 'successful' || s == 'success';
  }

  Future<void> _fetchAddresses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      // Handle case where user is not logged in
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> addressesJson = responseData['deliveryAddresses'] ?? [];
        setState(() {
          _userAddresses = addressesJson.map((json) => Address.fromJson(json)).toList();
          // Optionally pre-select the default address
          if (_userAddresses.isNotEmpty) {
            _selectedAddress = _userAddresses.firstWhere(
                (addr) => addr.isDefault,
                orElse: () => _userAddresses.first,
            );
          }
        });
      }
    } catch (e) {
      print('Error fetching user addresses: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoading = true);
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

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks.first;

      _addressController.text = '${place.street}, ${place.subLocality}';
      _cityController.text = place.locality ?? '';
      _postalCodeController.text = place.postalCode ?? '';
      _countryController.text = place.country ?? '';
      _showSnackBar('Location fetched successfully!');
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _placeOrder() async {
    // If using manual entry, validate the form
    if (!_useSavedAddress && !_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method.');
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
        setState(() => _errorMessage = 'Authentication token not found. Please log in again.');
        return;
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.items.isEmpty) {
        setState(() => _errorMessage = 'Your cart is empty. Cannot place an empty order.');
        return;
      }

      final List<Map<String, dynamic>> orderItems =
          cartProvider.items.values.map((item) => item.toJson()).toList();

      final missingVendor = orderItems.any((i) => i['vendor'] == null);
      if (missingVendor) {
        setState(() => _errorMessage = 'One or more items are missing vendor info. Please contact support.');
        return;
      }

      // Calculate fees based on the latest business logic
      double shippingPrice = 0.0;
      final shippingCity = (_useSavedAddress ? _selectedAddress?.city : _cityController.text.trim())?.toLowerCase();

      if (shippingCity != null) {
        if (shippingCity.contains('gwarinpa')) {
          shippingPrice = 2000.00;
        } else if (shippingCity.contains('abuja')) {
          shippingPrice = 5000.00;
        }
      }

      final double subtotal = cartProvider.totalAmount;
      final double serviceFee = subtotal * 0.15;
      final double totalPrice = subtotal + serviceFee + shippingPrice;

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
        'paymentMethod': _selectedPaymentMethod, // CORRECTED HERE
        'serviceFee': serviceFee,
        'shippingPrice': shippingPrice,
        'totalPrice': totalPrice,
      };

      // 1) Create order
      final createOrderUrl = Uri.parse('$baseUrl/api/orders');
      final createOrderResp = await http.post(
        createOrderUrl,
        headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> createOrderData = _safeJson(createOrderResp.body);

      if (createOrderResp.statusCode != 201) {
        setState(() => _errorMessage = createOrderData['message'] ?? 'Failed to place order.');
        return;
      }

      final String orderId = createOrderData['_id'];

      // 2) Launch Flutterwave via PaymentService
      final userEmail = prefs.getString('email') ?? 'customer@example.com';
      final fullName = prefs.getString('fullName') ?? 'Test User';
      final phone = prefs.getString('phoneNumber') ?? '08012345678';

      final paymentService = PaymentService();
      final ChargeResponse? chargeResponse = await paymentService.startFlutterwavePayment(
        context: context,
        amount: totalPrice,
        email: userEmail,
        name: fullName,
        phoneNumber: phone,
      );

      if (chargeResponse == null) {
        setState(() => _errorMessage = 'Payment was not initiated.');
        return;
      }

      if (!_isFwSuccess(chargeResponse.status)) {
        setState(() {
          final s = (chargeResponse.status ?? '').toLowerCase();
          _errorMessage = s == 'cancelled' ? 'Payment was cancelled.' : 'Payment failed. Please try again.';
        });
        return;
      }

      // 3) Mark order paid on your backend
      final String paymentId = chargeResponse.transactionId ?? chargeResponse.txRef ?? 'flw_${DateTime.now().millisecondsSinceEpoch}';

      final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
      final payResp = await http.put(
        payUrl,
        headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'id': paymentId,
          'status': chargeResponse.status,
          'update_time': DateTime.now().toIso8601String(),
          'email_address': userEmail,
        }),
      );

      if (payResp.statusCode == 200) {
        setState(() => _successMessage = 'Order placed and paid successfully!');
        cartProvider.clearCart();
        _showSnackBar(_successMessage!);
        widget.onOrderSuccess();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final payData = _safeJson(payResp.body);
        setState(() {
          _errorMessage = payData['message'] ?? 'Order placed, but payment confirmation failed. Please contact support.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Check backend server and network.';
      });
      print('Order placement error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    // Calculate fees for the order summary display
    final double subtotal = cartProvider.totalAmount;
    final double serviceFee = subtotal * 0.15;
    double shippingPrice = 0.0;
    final shippingCity = (_useSavedAddress ? _selectedAddress?.city : _cityController.text.trim())?.toLowerCase();

    if (shippingCity != null) {
      if (shippingCity.contains('gwarinpa')) {
        shippingPrice = 2000.00;
      } else if (shippingCity.contains('abuja')) {
        shippingPrice = 5000.00;
      }
    }

    final double totalPrice = subtotal + serviceFee + shippingPrice;

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

              // Address selection buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _useSavedAddress = false;
                        });
                        _fetchCurrentLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _useSavedAddress ? deepNavyBlue.withOpacity(0.1) : deepNavyBlue,
                        foregroundColor: _useSavedAddress ? deepNavyBlue : greenYellow,
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
                        setState(() {
                          _useSavedAddress = true;
                          _addressController.clear();
                          _cityController.clear();
                          _postalCodeController.clear();
                          _countryController.clear();
                        });
                        final selectedAddress = await _showAddressSelectionDialog();
                        if (selectedAddress != null) {
                          setState(() {
                            _selectedAddress = selectedAddress;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _useSavedAddress ? deepNavyBlue : deepNavyBlue.withOpacity(0.1),
                        foregroundColor: _useSavedAddress ? greenYellow : deepNavyBlue,
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

              // Conditional display of address input fields or selected address
              if (_useSavedAddress && _selectedAddress != null)
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
              else if (_useSavedAddress && _userAddresses.isEmpty)
                const Center(
                  child: Text('No saved addresses found. Please add one or use your current location.',
                      textAlign: TextAlign.center, style: TextStyle(color: deepNavyBlue)),
                )
              else
                Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputDecoration('Address'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your address' : null,
                      enabled: !_useSavedAddress,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _cityController,
                      decoration: _inputDecoration('City'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your city' : null,
                      enabled: !_useSavedAddress,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: _inputDecoration('Postal Code'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your postal code' : null,
                      enabled: !_useSavedAddress,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _countryController,
                      decoration: _inputDecoration('Country'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your country' : null,
                      enabled: !_useSavedAddress,
                    ),
                  ],
                ),
              const SizedBox(height: 30),

              const Text(
                'Payment Method',
                style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: _inputDecoration('Select Payment Method').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                ),
                dropdownColor: deepNavyBlue.withOpacity(0.9),
                style: const TextStyle(color: greenYellow),
                items: ['Card', 'Bank Transfer']
                    .map((method) => DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                validator: (value) =>
                    value == null ? 'Please select a payment method' : null,
              ),
              const SizedBox(height: 30),

              const Text(
                'Order Summary',
                style: TextStyle(color: deepNavyBlue, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: deepNavyBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSummaryRow('Subtotal (${cartProvider.itemCount} items):', '₦${subtotal.toStringAsFixed(2)}'),
                      _buildSummaryRow('Shipping:', '₦${shippingPrice.toStringAsFixed(2)}'),
                      _buildSummaryRow('Service Fee (15%):', '₦${serviceFee.toStringAsFixed(2)}'),
                      const Divider(height: 30, thickness: 1, color: greenYellow),
                      _buildTotalRow('Total:', '₦${totalPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: deepNavyBlue, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (cartProvider.itemCount > 0 && (_useSavedAddress ? _selectedAddress != null : true) && _selectedPaymentMethod != null)
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: deepNavyBlue, width: 2),
      ),
    );
  }

  // A dialog to let the user select a saved address
  Future<Address?> _showAddressSelectionDialog() async {
    if (_userAddresses.isEmpty) {
      _showSnackBar('You have no saved addresses. Add one from your profile.');
      return null;
    }
    return showDialog<Address>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Delivery Address'),
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
                  onTap: () {
                    Navigator.of(context).pop(address);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

