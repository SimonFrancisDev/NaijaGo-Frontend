// lib/screens/Main/delivery_addresses_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator package
import '../../constants.dart';
import '../../models/address.dart'; // Import the Address model
import 'add_edit_address_screen.dart'; // Import the AddEditAddressScreen
import 'edit_profile_screen.dart';

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = Color(0xFF000080); // Deep Navy Blue - primary for backgrounds, cards
const Color greenYellow = Color(0xFFADFF2F); // Green Yellow - accent for important text, buttons
const Color whiteBackground = Colors.white; // Explicitly defining white for main backgrounds, text on navy

class DeliveryAddressesScreen extends StatefulWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  State<DeliveryAddressesScreen> createState() => _DeliveryAddressesScreenState();
}

class _DeliveryAddressesScreenState extends State<DeliveryAddressesScreen> {
  List<Address> _addresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me'); // Fetch user profile to get addresses
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> addressesJson = responseData['deliveryAddresses'] ?? [];
        setState(() {
          _addresses = addressesJson.map((json) => Address.fromJson(json)).toList();
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch addresses.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Check backend server and network.';
      });
      print('Error fetching addresses: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(int index) async {
    // Show confirmation dialog before deleting
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: whiteBackground, // Dialog background white
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirm Deletion', style: TextStyle(color: deepNavyBlue, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this address?', style: TextStyle(color: deepNavyBlue)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: whiteBackground)),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return; // User cancelled deletion
    }

    setState(() {
      _isLoading = true; // Show loading while deleting
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found. Please log in again.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/addresses/$index');
      final response = await http.delete(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Address deleted successfully!')),
          );
        }
        _fetchAddresses(); // Refresh the list after deletion
      } else {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Failed to delete address.')),
          );
        }
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
      print('Error deleting address: $e');
    } finally {
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handles the process of fetching the user's current location and navigating
  /// to the AddEditAddressScreen with the location data.
  Future<void> _addAddressFromCurrentLocation() async {
    // Check for and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied. Please enable them in your settings.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied. We cannot request permissions.')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final bool? result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddEditAddressScreen(
            initialLatitude: position.latitude,
            initialLongitude: position.longitude,
          ),
        ),
      );
      if (result == true) {
        _fetchAddresses(); // Refresh list if address was added
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
      print('Error getting location: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text('Delivery Addresses', style: TextStyle(color: greenYellow)),
        backgroundColor: deepNavyBlue,
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: deepNavyBlue, size: 50),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: deepNavyBlue, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchAddresses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  foregroundColor: greenYellow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _addresses.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 80, color: deepNavyBlue.withOpacity(0.5)),
              const SizedBox(height: 20),
              Text(
                'No delivery addresses added yet.',
                style: TextStyle(color: deepNavyBlue, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Add your first address to get started!',
                style: TextStyle(color: deepNavyBlue.withOpacity(0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addAddressFromCurrentLocation, // New function for geolocation
                icon: const Icon(Icons.my_location, color: whiteBackground),
                label: const Text('Use Current Location', style: TextStyle(color: whiteBackground)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final bool? result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
                  );
                  if (result == true) {
                    _fetchAddresses(); // Refresh list if address was added
                  }
                },
                icon: const Icon(Icons.add_location_alt, color: whiteBackground),
                label: const Text('Add Manually', style: TextStyle(color: whiteBackground)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final address = _addresses[index];
          return Card(
            elevation: 6,
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: deepNavyBlue,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Icon(
                address.isDefault ? Icons.location_on : Icons.location_on_outlined,
                color: greenYellow,
                size: 30,
              ),
              title: Text(
                address.fullAddress,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: greenYellow,
                ),
              ),
              subtitle: Text(
                '${address.city}, ${address.postalCode}, ${address.country}',
                style: TextStyle(fontSize: 14, color: whiteBackground.withOpacity(0.7)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: whiteBackground),
                    onPressed: () async {
                      final bool? result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddEditAddressScreen(
                            address: address,
                            addressIndex: index,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchAddresses();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteAddress(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () async {
          final bool? result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
          );
          if (result == true) {
            _fetchAddresses(); // Refresh list if address was added
          }
        },
        label: const Text('Add New', style: TextStyle(color: whiteBackground)),
        icon: const Icon(Icons.add, color: whiteBackground),
        backgroundColor: deepNavyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 4,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
