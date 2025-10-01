import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // NEW: Import geolocator
import 'package:geocoding/geocoding.dart'; // NEW: Import geocoding
import '../../constants.dart'; // Ensure baseUrl is defined here

const Color deepNavyBlue = Color(0xFF03024C);
const Color greenYellow = Color(0xFFADFF2F);
const Color white = Colors.white;


class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _formattedAddressController = TextEditingController();
  double? _businessLocationLatitude;
  double? _businessLocationLongitude;
  String? _selectedGender;
  final List<String> _selectedCategories = [];
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _categoryOptions = [
    'Supermarkets',
    'Boutiques',
    'Phone Accessories',
    'Health and Pharmacies',
    'Electronics',
    'Fashion',
    'Food & Beverages',
    'Services',
    'Automotive',
    'Books & Stationery',
    'Home & Kitchen',
    'Sports & Outdoors',
    'Toys & Games',
    'Pet Supplies',
    'Art & Crafts',
    'Jewelry',
    'Beauty & Personal Care',
    'Baby Products',
    'Industrial & Scientific',
    'Musical Instruments',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _businessNameController.dispose();
    _formattedAddressController.dispose();
    super.dispose();
  }

  // UPDATED: Function to get the real business location using geolocator and geocoding
  Future<void> _getRealBusinessLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
          _isLoading = false;
        });
        return;
      }

      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied, we cannot request permissions.';
          _isLoading = false;
        });
        return;
      }

      // Get the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get the human-readable address from the coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = '${place.street}, ${place.locality}, ${place.country}';

        setState(() {
          _businessLocationLatitude = position.latitude;
          _businessLocationLongitude = position.longitude;
          _formattedAddressController.text = address;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business location retrieved successfully!')),
        );
      } else {
        setState(() {
          _errorMessage = 'Could not find a human-readable address for your location.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
      print('Location error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _submitVendorRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'You must accept the terms and conditions.';
      });
      return;
    }
    if (_selectedCategories.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one business category.';
      });
      return;
    }

    if (_businessLocationLatitude == null || _businessLocationLongitude == null || _formattedAddressController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a business location.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
      });
      return;
    }

    final Map<String, dynamic> requestBody = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _selectedGender,
      'businessName': _businessNameController.text.trim(),
      'businessCategories': _selectedCategories,
      'termsAccepted': _termsAccepted,
      'businessLocation': {
        'latitude': _businessLocationLatitude,
        'longitude': _businessLocationLongitude,
        'formattedAddress': _formattedAddressController.text.trim(),
      },
      // 'profilePicUrl': 'https://placehold.co/100x100/000080/FFFFFF?text=Vendor', // Placeholder for now
    };

    try {
      final Uri url = Uri.parse('$baseUrl/api/vendor/request');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _successMessage = responseData['message'] ?? 'Vendor request submitted successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_successMessage!)),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to submit vendor request.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Please ensure your backend is running and returning JSON.';
      });
      print('Vendor request network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Terms and Conditions', style: TextStyle(color: deepNavyBlue)),
          content: SingleChildScrollView(
            child: Text(
              '''
              Welcome to Our Vendor Program!

              By registering as a vendor with us, you agree to the following terms and conditions:

              1. **Eligibility:** You must be at least 18 years old and legally able to form binding contracts.
              2. **Account Responsibility:** You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.
              3. **Product/Service Standards:** All products or services offered must comply with local laws and our platform's quality standards.
              4. **Pricing and Payments:** You are responsible for setting and maintaining accurate pricing. Payments will be processed according to our payout schedule, subject to any fees.
              5. **Content and Intellectual Property:** You warrant that you own or have the necessary licenses to all content you upload or provide. You grant us a non-exclusive license to use, reproduce, and display your content on our platform.
              6. **Prohibited Activities:** You agree not to engage in any fraudulent, illegal, or harmful activities on our platform.
              7. **Termination:** We reserve the right to suspend or terminate your vendor account at our discretion, particularly for violations of these terms.
              8. **Disclaimer of Warranties:** Our platform is provided "as is" without any warranties.
              9. **Limitation of Liability:** We shall not be liable for any indirect, incidental, special, consequential, or punitive damages.
              10. **Governing Law:** These terms shall be governed by the laws of Nigeria.

              Please read these terms carefully. If you have any questions, contact our support team.
              ''',
              style: TextStyle(color: deepNavyBlue.withOpacity(0.8)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: deepNavyBlue)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: Text('Become a Vendor', style: TextStyle(color: white)),
        backgroundColor: deepNavyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Vendor Registration Form',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: deepNavyBlue,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: deepNavyBlue),
                  decoration: _inputDecoration('First Name', color),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter your first name' : null,
                ),
                const SizedBox(height: 15),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: deepNavyBlue),
                  decoration: _inputDecoration('Last Name', color),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter your last name' : null,
                ),
                const SizedBox(height: 15),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _inputDecoration('Gender', color).copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  ),
                  dropdownColor: white,
                  style: const TextStyle(color: deepNavyBlue),
                  items: _genderOptions.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender, style: const TextStyle(color: deepNavyBlue)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Please select your gender' : null,
                ),
                const SizedBox(height: 15),

                // Business Name
                TextFormField(
                  controller: _businessNameController,
                  style: const TextStyle(color: deepNavyBlue),
                  decoration: _inputDecoration('Business Name', color),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter your business name' : null,
                ),
                const SizedBox(height: 15),

                // Business Location Field
                Text(
                  'Business Location',
                  style: TextStyle(color: deepNavyBlue, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _formattedAddressController,
                  style: const TextStyle(color: deepNavyBlue),
                  decoration: _inputDecoration('Address', color).copyWith(
                    suffixIcon: IconButton(
                      icon: _isLoading ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: deepNavyBlue, strokeWidth: 2),
                      ) : const Icon(Icons.location_on, color: deepNavyBlue),
                      onPressed: _getRealBusinessLocation,
                      tooltip: 'Get current location',
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Please provide a business address' : null,
                  readOnly: true,
                ),
                const SizedBox(height: 15),

                // Categories (Multi-select Checkboxes)
                Text(
                  'Business Categories:',
                  style: TextStyle(color: deepNavyBlue, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _categoryOptions.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                      selectedColor: greenYellow,
                      checkmarkColor: deepNavyBlue,
                      labelStyle: const TextStyle(
                        color: deepNavyBlue,
                      ),
                      backgroundColor: white,
                      side: BorderSide(color: deepNavyBlue.withOpacity(0.5)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),

                // Profile Picture (Placeholder for now)
                Text(
                  'Profile Picture: (Image upload will be implemented in a future update)',
                  style: TextStyle(color: deepNavyBlue.withOpacity(0.8), fontSize: 14),
                ),
                const SizedBox(height: 15),

                // Terms and Conditions Checkbox
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: deepNavyBlue,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Theme(
                        data: ThemeData(
                          unselectedWidgetColor: Colors.transparent,
                        ),
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _termsAccepted = newValue!;
                            });
                          },
                          activeColor: greenYellow,
                          checkColor: deepNavyBlue,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTermsAndConditions,
                        child: Text(
                          'I accept the terms and conditions',
                          style: TextStyle(color: deepNavyBlue.withOpacity(0.8), decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Display messages
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit Button
                _isLoading
                    ? CircularProgressIndicator(color: deepNavyBlue)
                    : ElevatedButton(
                        onPressed: _submitVendorRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepNavyBlue,
                          foregroundColor: white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: const Text(
                          'Request to be a Vendor',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, ColorScheme color) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: deepNavyBlue),
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: deepNavyBlue.withOpacity(0.5), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: deepNavyBlue.withOpacity(0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: deepNavyBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}