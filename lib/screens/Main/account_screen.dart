import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // âœ… Added
import '../../constants.dart';
// Import your main.dart file to access the ThemeChanger and SettingsScreen classes
import '../../main.dart';
// import '../../admin/screens/admin_panel_screen.dart'; // Import for Admin Panel
import '../../models/address.dart'; // Import Address model
import '../../auth/screens/login_screen.dart'; // Import LoginScreen
import 'my_orders_screen.dart'; // Import MyOrdersScreen
import 'saved_items_screen.dart'; // Import SavedItemsScreen
import 'delivery_addresses_screen.dart'; // Import DeliveryAddressesScreen
import 'edit_profile_screen.dart'; // Import EditProfileScreen
import 'my_wallet_screen.dart'; // Import MyWalletScreen
import 'reviews_ratings_screen.dart'; // NEW: Import ReviewsRatingsScreen
import 'create_dispute_screen.dart';
import 'dispute_list_screen.dart';
import 'faq_screen.dart';
import 'vendor_my_products_screen.dart';
import '../../screens/vendor/orders_recived_screen.dart.dart';
import 'pharmacist_dashboard.dart'; // âœ… Import PharmacistDashboard

// Define your color constants (consistent with vendor registration)
const Color deepNavyBlue = Color(0xFF03024C);
const Color greenYellow = Color(0xFFADFF2F);
const Color white = Colors.white;
const Color lightGray = Color(0xFFF5F5F5); // Adding a light gray for subtle backgrounds if needed

class AccountScreen extends StatefulWidget {
Â final VoidCallback onLogout;

Â const AccountScreen({super.key, required this.onLogout});

Â @override
Â State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
Â bool _isLoading = true;
Â String? _errorMessage;

Â // User Profile Data
Â String _firstName = '';
Â String _lastName = '';
Â String _email = '';
Â String _phoneNumber = '';
Â String _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User'; // Default placeholder
Â bool _isAdmin = false;
Â bool _isPharmacist = false; // â¬…ï¸ VARIABLE DECLARED

Â // Buyer Specific Data
Â double _userWalletBalance = 0.0;
Â List<String> _savedItems = []; // List of product IDs
Â List<Address> _deliveryAddresses = [];

Â // Vendor Specific Data
Â bool _isVendor = false;
Â String _vendorStatus = 'none';
Â String? _businessName;
Â int _totalProducts = 0;
Â int _productsSold = 0;
Â int _productsUnsold = 0;
Â int _followersCount = 0;
Â double _vendorWalletBalance = 0.0;
Â double _appWalletBalance = 0.0;
Â List<dynamic> _notifications = []; // Notifications are common but displayed differently

Â // âœ… Store token in state so itâ€™s accessible across the widget
Â String? _token;

Â @override
Â void initState() {
Â Â super.initState();
Â Â WidgetsBinding.instance.addObserver(this);
Â Â _fetchUserData();
Â }

Â @override
Â void dispose() {
Â Â WidgetsBinding.instance.removeObserver(this);
Â Â super.dispose();
Â }

Â @override
Â void didChangeAppLifecycleState(AppLifecycleState state) {
Â Â if (state == AppLifecycleState.resumed) {
Â Â Â _fetchUserData(); // Refresh data when app resumes
Â Â }
Â }

Â Future<void> _fetchUserData() async {
Â Â setState(() {
Â Â Â _isLoading = true;
Â Â Â _errorMessage = null;
Â Â });

Â Â final SharedPreferences prefs = await SharedPreferences.getInstance();
Â Â final String? token = prefs.getString('jwt_token');
Â Â _token = token; // âœ… keep a copy in state

Â Â if (token == null) {
Â Â Â setState(() {
Â Â Â Â _errorMessage = 'Authentication token not found. Please log in again.';
Â Â Â Â _isLoading = false;
Â Â Â });
Â Â Â return;
Â Â }

Â Â try {
Â Â Â final Uri url = Uri.parse('$baseUrl/api/auth/me');
Â Â Â final response = await http.get(
Â Â Â Â url,
Â Â Â Â headers: <String, String>{
Â Â Â Â Â 'Content-Type': 'application/json; charset=UTF-8',
Â Â Â Â Â 'Authorization': 'Bearer $token',
Â Â Â Â },
Â Â Â );

Â Â Â if (response.statusCode == 200) {
Â Â Â Â final Map<String, dynamic> responseData = jsonDecode(response.body);
Â Â Â Â setState(() {
Â Â Â Â Â // Common User Data
Â Â Â Â Â _firstName = responseData['firstName'] ?? '';
Â Â Â Â Â _lastName = responseData['lastName'] ?? '';
Â Â Â Â Â _email = responseData['email'] ?? '';
Â Â Â Â Â _phoneNumber = responseData['phoneNumber'] ?? '';

Â Â Â Â Â final String? fetchedProfilePicPath = responseData['profilePicUrl'];
Â Â Â Â if (fetchedProfilePicPath != null && fetchedProfilePicPath.isNotEmpty) {
Â Â Â Â Â if (fetchedProfilePicPath.startsWith('http')) {
Â Â Â Â Â Â // If it's already a full URL (e.g., S3 link), use it as is.
Â Â Â Â Â Â _profilePicUrl = fetchedProfilePicPath; 
Â Â Â Â Â } else {
Â Â Â Â Â Â // If it's a relative path, prepend the base URL.
Â Â Â Â Â Â // Use the URL AS-IS; do NOT append a new timestamp.
Â Â Â Â Â Â _profilePicUrl = '$baseUrl$fetchedProfilePicPath';
Â Â Â Â Â }
Â Â Â Â } else {
Â Â Â Â Â _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User';
Â Â Â Â }

Â Â Â Â Â _isAdmin = responseData['isAdmin'] ?? false;
Â Â Â Â Â _isPharmacist = responseData['isPharmacist'] ?? false; // ğŸŒŸ PHARMACIST FIX APPLIED HERE

Â Â Â Â Â // Buyer Specific Data
Â Â Â Â Â _userWalletBalance = (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
Â Â Â Â Â _savedItems = List<String>.from(responseData['savedItems'] ?? []);
Â Â Â Â Â _deliveryAddresses = (responseData['deliveryAddresses'] as List?)
Â Â Â Â Â Â Â ?.map((addrJson) => Address.fromJson(addrJson))
Â Â Â Â Â Â Â .toList() ??
Â Â Â Â Â Â Â [];

Â Â Â Â Â // Vendor Specific Data
Â Â Â Â Â _isVendor = responseData['isVendor'] ?? false;
Â Â Â Â Â _vendorStatus = responseData['vendorStatus'] ?? 'none';
Â Â Â Â Â _businessName = responseData['businessName'];
Â Â Â Â Â _totalProducts = responseData['totalProducts'] ?? 0;
Â Â Â Â Â _productsSold = responseData['productsSold'] ?? 0;
Â Â Â Â Â _productsUnsold = responseData['productsUnsold'] ?? 0;
Â Â Â Â Â _followersCount = responseData['followersCount'] ?? 0;
Â Â Â Â Â _vendorWalletBalance = (responseData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
Â Â Â Â Â _appWalletBalance = (responseData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
Â Â Â Â Â _notifications = responseData['notifications'] ?? [];
Â Â Â Â });
Â Â Â } else {
Â Â Â Â final responseData = jsonDecode(response.body);
Â Â Â Â setState(() {
Â Â Â Â Â _errorMessage = responseData['message'] ?? 'Failed to fetch user data.';
Â Â Â Â });
Â Â Â Â if (response.statusCode == 401) {
Â Â Â Â Â prefs.remove('jwt_token');
Â Â Â Â Â // Optionally navigate to login screen
Â Â Â Â }
Â Â Â }
Â Â } catch (e) {
Â Â Â setState(() {
Â Â Â Â _errorMessage = 'An error occurred: $e. Please check your network connection.';
Â Â Â });
Â Â Â print('Fetch user data network error: $e');
Â Â } finally {
Â Â Â setState(() {
Â Â Â Â _isLoading = false;
Â Â Â });
Â Â }
Â }

Â Future<void> _handleAccountDeletion() async {
Â Â final bool confirm = await showDialog(
Â Â Â context: context,
Â Â Â builder: (context) => AlertDialog(
Â Â Â Â title: const Text('Delete Account Permanently?'),
Â Â Â Â content: const Text(
Â Â Â Â Â Â 'This action is irreversible. All your data, including profile info, orders, and saved items, will be permanently deleted. Are you sure?'),
Â Â Â Â actions: [
Â Â Â Â Â TextButton(
Â Â Â Â Â Â onPressed: () => Navigator.of(context).pop(false),
Â Â Â Â Â Â child: const Text('Cancel'),
Â Â Â Â Â ),
Â Â Â Â Â TextButton(
Â Â Â Â Â Â onPressed: () => Navigator.of(context).pop(true),
Â Â Â Â Â Â child: const Text('Delete', style: TextStyle(color: Colors.red)),
Â Â Â Â Â ),
Â Â Â Â ],
Â Â Â ),
Â Â ) ?? false;

Â Â if (confirm) {
Â Â Â // Show loading indicator
Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â const SnackBar(content: Text('Deleting account...'), duration: Duration(seconds: 2)),
Â Â Â );


Â Â Â final prefs = await SharedPreferences.getInstance();
Â Â Â final token = prefs.getString('jwt_token');
Â Â Â final url = Uri.parse('$baseUrl/api/auth/delete-account');

Â Â Â try {
Â Â Â Â final response = await http.delete(
Â Â Â Â Â url,
Â Â Â Â Â headers: {
Â Â Â Â Â Â 'Content-Type': 'application/json',
Â Â Â Â Â Â 'Authorization': 'Bearer $token',
Â Â Â Â Â },
Â Â Â Â );

Â Â Â Â if (response.statusCode == 200) {
Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Account successfully deleted.')));
Â Â Â Â Â // Log out the user and navigate to the login screen
Â Â Â Â Â await _handleLogout();
Â Â Â Â } else {
Â Â Â Â Â final responseBody = json.decode(response.body);
Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(SnackBar(
Â Â Â Â Â Â Â content: Text(
Â Â Â Â Â Â Â Â Â responseBody['message'] ?? 'Failed to delete account. Please try again.')));
Â Â Â Â }
Â Â Â } catch (e) {
Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â const SnackBar(content: Text('An error occurred. Check your network connection.')));
Â Â Â Â print('Error during account deletion: $e');
Â Â Â }
Â Â }
Â }

Â Future<void> _handleLogout() async {
Â Â final SharedPreferences prefs = await SharedPreferences.getInstance();
Â Â await prefs.remove('jwt_token');

Â Â widget.onLogout();
Â }

Â // einsteinenginefordevs@gmail.com
Â // // A static or global function that does nothing, as it's not needed for logout navigation
Â // static void _emptyOnLoginSuccess() {
Â // Â // This function is intentionally left empty.
Â // Â // It fulfills the `required` callback for LoginScreen when navigating to it during logout,
Â // Â // but no actual login success action needs to occur from this navigation.
Â // }

Â @override
Â Widget build(BuildContext context) {
Â Â // Define your custom ColorScheme based on the provided colors
Â Â final ColorScheme customColorScheme = const ColorScheme(
Â Â Â primary: deepNavyBlue, // Dominant color for interactive elements, top app bar
Â Â Â onPrimary: white, // Text and icons on top of primary color
Â Â Â secondary: greenYellow, // Accent color for floating buttons, highlights
Â Â Â onSecondary: deepNavyBlue, // Text and icons on top of secondary color
Â Â Â surface: white, // Background for cards, sheets, elevated elements
Â Â Â onSurface: deepNavyBlue, // Text and icons on top of surface color
Â Â Â background: lightGray, // General screen background
Â Â Â onBackground: deepNavyBlue, // Text and icons on top of background color
Â Â Â error: Colors.red, // Error states
Â Â Â onError: white, // Text and icons on top of error color
Â Â Â brightness: Brightness.light, // Overall theme brightness
Â Â );

Â Â final color = customColorScheme; // Use your custom color scheme

Â Â if (_isLoading) {
Â Â Â return Scaffold(
Â Â Â Â backgroundColor: color.background, // Use custom background
Â Â Â Â body: Center(child: CircularProgressIndicator(color: color.primary)),
Â Â Â );
Â Â }

Â Â if (_errorMessage != null) {
Â Â Â return Scaffold(
Â Â Â Â backgroundColor: color.background, // Use custom background
Â Â Â Â body: Center(
Â Â Â Â Â child: Padding(
Â Â Â Â Â Â padding: const EdgeInsets.all(24.0),
Â Â Â Â Â Â child: Column(
Â Â Â Â Â Â Â mainAxisAlignment: MainAxisAlignment.center,
Â Â Â Â Â Â Â children: [
Â Â Â Â Â Â Â Â Icon(Icons.error_outline, color: color.error, size: 50),
Â Â Â Â Â Â Â Â const SizedBox(height: 10),
Â Â Â Â Â Â Â Â Text(
Â Â Â Â Â Â Â Â Â _errorMessage!,
Â Â Â Â Â Â Â Â Â textAlign: TextAlign.center,
Â Â Â Â Â Â Â Â Â style: TextStyle(color: color.error, fontSize: 16),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â const SizedBox(height: 20),
Â Â Â Â Â Â Â Â ElevatedButton(
Â Â Â Â Â Â Â Â Â onPressed: _fetchUserData,
Â Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
Â Â Â Â Â Â Â Â Â Â backgroundColor: color.primary,
Â Â Â Â Â Â Â Â Â Â foregroundColor: color.onPrimary,
Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â Â child: const Text('Retry'),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â ],
Â Â Â Â Â Â ),
Â Â Â Â Â ),
Â Â Â Â ),
Â Â Â );
Â Â }

Â Â return Scaffold(
Â Â Â backgroundColor: color.background, // Main scaffold background
Â Â Â body: SingleChildScrollView(
Â Â Â Â padding: const EdgeInsets.all(16.0),
Â Â Â Â child: Column(
Â Â Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â Â Â children: [
Â Â Â Â Â Â // ğŸ§‘ Profile Section
Â Â Â Â Â Â _buildProfileSection(color),
Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

Â Â Â Â Â Â // ğŸ›ï¸ FOR BUYERS â€“ Tabs or List Items (Always shown, but content changes)
Â Â Â Â Â Â _buildBuyerSection(color),
Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

Â Â Â Â Â Â // ğŸ›’ FOR VENDORS â€“ Show if user is a vendor
Â Â Â Â Â Â if (_isVendor && _vendorStatus == 'approved')
Â Â Â Â Â Â Â _buildVendorToolsSection(color)
Â Â Â Â Â Â else
Â Â Â Â Â Â Â _buildBecomeVendorCTA(color),
Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

Â Â Â Â Â Â // ğŸŒŸ FOR PHARMACISTS â€“ Show if user is a pharmacist
Â Â Â Â Â Â if (_isPharmacist)
Â Â Â Â Â Â Â _buildPharmacistToolsSection(color),
Â Â Â Â Â Â if (_isPharmacist)
Â Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

Â Â Â Â Â Â // âš™ï¸ COMMON TOOLS (For All Users)
Â Â Â Â Â Â _buildCommonToolsSection(color),
Â Â Â Â Â Â const SizedBox(height: 20),

Â Â Â Â Â Â // Log Out Button
Â Â Â Â Â Â SizedBox(
Â Â Â Â Â Â Â width: double.infinity,
Â Â Â Â Â Â Â child: ElevatedButton.icon(
Â Â Â Â Â Â Â Â onPressed: _handleLogout,
Â Â Â Â Â Â Â Â icon: Icon(Icons.logout, color: white), // White icon for contrast on red
Â Â Â Â Â Â Â Â label: const Text('Log Out', style: TextStyle(color: white, fontSize: 18)), // White text for contrast
Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
Â Â Â Â Â Â Â Â Â backgroundColor: Colors.red.shade700, // Explicit red for logout action
Â Â Â Â Â Â Â Â Â padding: const EdgeInsets.symmetric(vertical: 15),
Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(
Â Â Â Â Â Â Â Â Â Â borderRadius: BorderRadius.circular(12),
Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â Â elevation: 5,
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â ),

Â Â Â Â Â Â // --- ADD THIS NEW WIDGET HERE ---

Â Â Â Â Â Â const SizedBox(height: 10), // Add a small space between the two buttons

Â Â Â Â Â Â // Delete Account Button
Â Â Â Â Â Â SizedBox(
Â Â Â Â Â Â Â width: double.infinity,
Â Â Â Â Â Â Â child: OutlinedButton.icon(
Â Â Â Â Â Â Â Â onPressed: _handleAccountDeletion,
Â Â Â Â Â Â Â Â icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
Â Â Â Â Â Â Â Â label: Text('Delete Account', style: TextStyle(color: Colors.red.shade700, fontSize: 18)),
Â Â Â Â Â Â Â Â style: OutlinedButton.styleFrom(
Â Â Â Â Â Â Â Â Â padding: const EdgeInsets.symmetric(vertical: 15),
Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(
Â Â Â Â Â Â Â Â Â Â borderRadius: BorderRadius.circular(12),
Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â Â side: BorderSide(color: Colors.red.shade700, width: 2),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â ),

Â Â Â Â Â Â // --- Unique Ideas (Placeholders for now) ---
Â Â Â Â Â Â const SizedBox(height: 40),
Â Â Â Â Â Â Text(
Â Â Â Â Â Â Â 'Unique Ideas (Coming Soon):',
Â Â Â Â Â Â Â style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â Â Â ),
Â Â Â Â Â Â const SizedBox(height: 10),
Â Â Â Â Â Â _buildComingSoonItem(color, 'âœ… Buyerâ€“Seller Switch Toggle'),
Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ“¦ Live Order Map Tracker'),
Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ‰ Achievements/Badges'),
Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ’¬ Community Forum Link'),
Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ“ˆ Quick Stats Card (for Vendors)'),
Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ”” Smart Alerts'),
Â Â Â Â Â Â const SizedBox(height: 40),
Â Â Â Â Â ],
Â Â Â Â ),
Â Â Â ),
Â Â );
Â }

Â // --- Helper Widgets for Sections ---

Â Widget _buildProfileSection(ColorScheme color) {
Â Â return Column(
Â Â Â children: [
Â Â Â Â Center(
Â Â Â Â Â child: CircleAvatar(
Â Â Â Â Â Â radius: 50,
Â Â Â Â Â Â backgroundColor: color.surface, // Fallback background for avatar
Â Â Â Â Â Â child: ClipOval(
Â Â Â Â Â Â Â child: SizedBox.expand(
Â Â Â Â Â Â Â Â child: CachedNetworkImage(
Â Â Â Â Â Â Â Â Â imageUrl: _profilePicUrl,
Â Â Â Â Â Â Â Â Â fit: BoxFit.cover,
Â Â Â Â Â Â Â Â Â placeholder: (context, url) => Center(
Â Â Â Â Â Â Â Â Â Â child: CircularProgressIndicator(color: color.primary),
Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â Â errorWidget: (context, url, error) {
Â Â Â Â Â Â Â Â Â Â return Icon(Icons.person, size: 60, color: color.onSurface.withOpacity(0.5));
Â Â Â Â Â Â Â Â Â },
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â ),
Â Â Â Â Â ),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â Text(
Â Â Â Â Â '${_firstName} ${_lastName}',
Â Â Â Â Â style: TextStyle(
Â Â Â Â Â Â fontSize: 24,
Â Â Â Â Â Â fontWeight: FontWeight.bold,
Â Â Â Â Â Â color: color.onBackground, // Use onBackground for main text
Â Â Â Â Â ),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 5),
Â Â Â Â Text(
Â Â Â Â Â _email,
Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
Â Â Â Â ),
Â Â Â Â Text(
Â Â Â Â Â _phoneNumber,
Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 15),
Â Â Â Â SizedBox(
Â Â Â Â Â width: double.infinity,
Â Â Â Â Â child: OutlinedButton.icon(
Â Â Â Â Â Â onPressed: () async {
Â Â Â Â Â Â Â final bool? result = await Navigator.of(context).push(
Â Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const EditProfileScreen()),
Â Â Â Â Â Â Â );
Â Â Â Â Â Â Â if (result == true) {
Â Â Â Â Â Â Â Â _fetchUserData(); // Refresh AccountScreen data after profile is updated
Â Â Â Â Â Â Â }
Â Â Â Â Â Â },
Â Â Â Â Â Â icon: Icon(Icons.edit, color: color.primary),
Â Â Â Â Â Â label: Text('Edit Profile', style: TextStyle(color: color.primary)),
Â Â Â Â Â Â style: OutlinedButton.styleFrom(
Â Â Â Â Â Â Â side: BorderSide(color: color.primary), // Border matches primary color
Â Â Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
Â Â Â Â Â Â ),
Â Â Â Â Â ),
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }

Â Widget _buildBuyerSection(ColorScheme color) {
Â Â return Column(
Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â children: [
Â Â Â Â Text(
Â Â Â Â Â 'Buyer Tools',
Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.shopping_bag_outlined,
Â Â Â Â Â 'My Orders',
Â Â Â Â Â 'Track all current & past orders',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.favorite_outline,
Â Â Â Â Â 'Saved Items (Wishlist)',
Â Â Â Â Â 'Easily revisit products you liked',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.account_balance_wallet_outlined,
Â Â Â Â Â 'My Wallet / Payment Methods',
Â Â Â Â Â 'Wallet balance: â‚¦${_userWalletBalance.toStringAsFixed(2)}',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const MyWalletScreen()),
Â Â Â Â Â Â );
Â Â Â Â Â Â _fetchUserData(); // Refresh account data after returning from wallet screen
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.location_on_outlined,
Â Â Â Â Â 'Delivery Addresses',
Â Â Â Â Â 'Manage your shipping locations',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const DeliveryAddressesScreen()),
Â Â Â Â Â Â );
Â Â Â Â Â Â _fetchUserData(); // Refresh account data after returning from addresses screen
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.star_outline,
Â Â Â Â Â 'Reviews & Ratings',
Â Â Â Â Â 'View products you reviewed',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const ReviewsRatingsScreen()),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.assignment_return_outlined,
Â Â Â Â Â 'Returns & Disputes',
Â Â Â Â Â 'View initiated return requests',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(
Â Â Â Â Â Â Â Â builder: (context) => const DisputeListScreen(),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.help_outline,
Â Â Â Â Â 'Help Center',
Â Â Â Â Â 'FAQs, live chat, contact support',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(
Â Â Â Â Â Â Â Â builder: (context) => const FAQScreen(),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }
Â Widget _buildVendorToolsSection(ColorScheme color) {
Â Â return Column(
Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â children: [
Â Â Â Â Text(
Â Â Â Â Â 'Vendor Tools',
Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.inventory_2_outlined,
Â Â Â Â Â 'My Products',
Â Â Â Â Â 'View/manage inventory (${_totalProducts} total, ${_productsUnsold} unsold)',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(
Â Â Â Â Â Â Â Â builder: (context) => const VendorMyProductsScreen(),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.receipt_long_outlined,
Â Â Â Â Â 'Orders Received',
Â Â Â Â Â 'View buyer orders (${_productsSold} products sold)',
Â Â Â Â Â Â Â () async {
Â Â Â Â Â Â await Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(
Â Â Â Â Â Â Â Â builder: (context) => const OrdersRecivedScreen(),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.payments_outlined,
Â Â Â Â Â 'Earnings Dashboard',
Â Â Â Â Â 'Vendor Wallet: â‚¦${_vendorWalletBalance.toStringAsFixed(2)} | App Wallet: â‚¦${_appWalletBalance.toStringAsFixed(2)}',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Earnings Dashboard functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.campaign_outlined,
Â Â Â Â Â 'Promotions & Ads',
Â Â Â Â Â 'Promote a product, view ad performance',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Promotions & Ads functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.store_outlined,
Â Â Â Â Â 'Store Profile',
Â Â Â Â Â 'Edit store logo, bio, name',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Store Profile functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.message_outlined,
Â Â Â Â Â 'Messages from Buyers',
Â Â Â Â Â 'Buyer inquiries or complaints',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Messages from Buyers functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }

Â // ğŸŒŸ NEW HELPER METHOD FOR PHARMACIST DASHBOARD
Â Widget _buildPharmacistToolsSection(ColorScheme color) {
Â Â return Column(
Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â children: [
Â Â Â Â Text(
Â Â Â Â Â 'Pharmacist Tools',
Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.local_pharmacy_outlined,
Â Â Â Â Â 'Pharmacist Dashboard',
Â Â Â Â Â 'Manage incoming prescription requests',
Â Â Â Â Â () {
Â Â Â Â Â Â Navigator.of(context).push(
Â Â Â Â Â Â Â MaterialPageRoute(
Â Â Â Â Â Â Â Â builder: (context) => const PharmacistDashboard(),
Â Â Â Â Â Â Â ),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }

Â Widget _buildBecomeVendorCTA(ColorScheme color) {
Â Â return Column(
Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â children: [
Â Â Â Â Text(
Â Â Â Â Â 'Become a Vendor',
Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â Card(
Â Â Â Â Â elevation: 2,
Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
Â Â Â Â Â color: color.surface, // Card background color
Â Â Â Â Â child: Padding(
Â Â Â Â Â Â padding: const EdgeInsets.all(16.0),
Â Â Â Â Â Â child: Column(
Â Â Â Â Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â Â Â Â Â children: [
Â Â Â Â Â Â Â Â Text(
Â Â Â Â Â Â Â Â Â 'Want to sell your products on NaijaGo?',
Â Â Â Â Â Â Â Â Â style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color.onSurface),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â const SizedBox(height: 10),
Â Â Â Â Â Â Â Â Text(
Â Â Â Â Â Â Â Â Â 'Register as a vendor to list your products and manage your sales.',
Â Â Â Â Â Â Â Â Â style: TextStyle(fontSize: 14, color: color.onSurface.withOpacity(0.7)),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â const SizedBox(height: 15),
Â Â Â Â Â Â Â Â SizedBox(
Â Â Â Â Â Â Â Â Â width: double.infinity,
Â Â Â Â Â Â Â Â Â child: ElevatedButton.icon(
Â Â Â Â Â Â Â Â Â Â onPressed: () {
Â Â Â Â Â Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â Â Â Â Â Â const SnackBar(content: Text('Vendor Registration coming soon!')),
Â Â Â Â Â Â Â Â Â Â Â );
Â Â Â Â Â Â Â Â Â Â },
Â Â Â Â Â Â Â Â Â Â icon: Icon(Icons.store_mall_directory_outlined, color: color.onPrimary),
Â Â Â Â Â Â Â Â Â Â label: Text('Register as Vendor', style: TextStyle(color: color.onPrimary)),
Â Â Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
Â Â Â Â Â Â Â Â Â Â Â backgroundColor: color.primary,
Â Â Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
Â Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â Â ),
Â Â Â Â Â Â Â ],
Â Â Â Â Â Â ),
Â Â Â Â Â ),
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }

Â Widget _buildCommonToolsSection(ColorScheme color) {
Â Â return Column(
Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
Â Â Â children: [
Â Â Â Â Text(
Â Â Â Â Â 'Common Tools',
Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
Â Â Â Â ),
Â Â Â Â const SizedBox(height: 10),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.notifications_none,
Â Â Â Â Â 'Notification Settings',
Â Â Â Â Â 'Manage your notification preferences',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Notification Settings functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â // âœ… The Dark Mode Toggle now navigates to the SettingsScreen
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.brightness_4_outlined,
Â Â Â Â Â 'Dark Mode Toggle',
Â Â Â Â Â 'Switch between light and dark themes',
Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('This Feature is Coming Soon')),
Â Â Â Â Â Â );
Â Â Â Â Â }
Â Â Â Â Â // Â Â () {
Â Â Â Â Â // Â // Navigate to the SettingsScreen class, which is defined in main.dart
Â Â Â Â Â // Â Navigator.of(context).push(
Â Â Â Â Â // Â Â MaterialPageRoute(builder: (context) => const SettingsScreen()),
Â Â Â Â Â // Â );
Â Â Â Â Â // },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.language_outlined,
Â Â Â Â Â 'Language & Region',
Â Â Â Â Â 'Change app language and region settings',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Language & Region functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â Â _buildAccountListItem(
Â Â Â Â Â context,
Â Â Â Â Â color,
Â Â Â Â Â Icons.share_outlined,
Â Â Â Â Â 'Invite a Friend',
Â Â Â Â Â 'Share NaijaGo with your friends',
Â Â Â Â Â Â Â () {
Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
Â Â Â Â Â Â Â const SnackBar(content: Text('Invite a Friend functionality coming soon!')),
Â Â Â Â Â Â );
Â Â Â Â Â },
Â Â Â Â ),
Â Â Â ],
Â Â );
Â }

Â // Helper for consistent list item styling
Â Widget _buildAccountListItem(BuildContext context, ColorScheme color, IconData icon, String title, String subtitle, VoidCallback onTap) {
Â Â return Card(
Â Â Â elevation: 2,
Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
Â Â Â margin: const EdgeInsets.symmetric(vertical: 6.0),
Â Â Â color: color.surface, // Card background color
Â Â Â child: ListTile(
Â Â Â Â leading: Icon(icon, color: color.primary, size: 28), // Icon color
Â Â Â Â title: Text(title, style: TextStyle(color: color.onSurface, fontWeight: FontWeight.w600)), // Title text color
Â Â Â Â subtitle: Text(subtitle, style: TextStyle(color: color.onSurface.withOpacity(0.7))), // Subtitle text color
Â Â Â Â trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color.onSurface.withOpacity(0.5)), // Arrow icon color
Â Â Â Â onTap: onTap,
Â Â Â ),
Â Â );
Â }

Â Widget _buildComingSoonItem(ColorScheme color, String text) {
Â Â return Padding(
Â Â Â padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
Â Â Â child: Row(
Â Â Â Â children: [
Â Â Â Â Â Icon(Icons.check_circle_outline, size: 20, color: greenYellow), // Checkmark icon color
Â Â Â Â Â const SizedBox(width: 10),
Â Â Â Â Â Expanded(
Â Â Â Â Â Â child: Text(
Â Â Â Â Â Â Â text,
Â Â Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.8)), // Text color
Â Â Â Â Â Â ),
Â Â Â Â Â ),
Â Â Â Â ],
Â Â Â ),
Â Â );
Â }
}



// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // âœ… Added
// import '../../constants.dart';
// // Import your main.dart file to access the ThemeChanger and SettingsScreen classes
// import '../../main.dart';
// // import '../../admin/screens/admin_panel_screen.dart'; // Import for Admin Panel
// import '../../models/address.dart'; // Import Address model
// import '../../auth/screens/login_screen.dart'; // Import LoginScreen
// import 'my_orders_screen.dart'; // Import MyOrdersScreen
// import 'saved_items_screen.dart'; // Import SavedItemsScreen
// import 'delivery_addresses_screen.dart'; // Import DeliveryAddressesScreen
// import 'edit_profile_screen.dart'; // Import EditProfileScreen
// import 'my_wallet_screen.dart'; // Import MyWalletScreen
// import 'reviews_ratings_screen.dart'; // NEW: Import ReviewsRatingsScreen
// import 'create_dispute_screen.dart';
// import 'dispute_list_screen.dart';
// import 'faq_screen.dart';
// import 'vendor_my_products_screen.dart';
// import '../../screens/vendor/orders_recived_screen.dart.dart';
// import 'pharmacist_dashboard.dart'; // âœ… Import PharmacistDashboard

// // Define your color constants (consistent with vendor registration)
// const Color deepNavyBlue = Color(0xFF03024C);
// const Color greenYellow = Color(0xFFADFF2F);
// const Color white = Colors.white;
// const Color lightGray = Color(0xFFF5F5F5); // Adding a light gray for subtle backgrounds if needed

// class AccountScreen extends StatefulWidget {
// Â final VoidCallback onLogout;

// Â const AccountScreen({super.key, required this.onLogout});

// Â @override
// Â State<AccountScreen> createState() => _AccountScreenState();
// }

// class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
// Â bool _isLoading = true;
// Â String? _errorMessage;

// Â // User Profile Data
// Â String _firstName = '';
// Â String _lastName = '';
// Â String _email = '';
// Â String _phoneNumber = '';
// Â String _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User'; // Default placeholder
// Â bool _isAdmin = false;
// Â bool _isPharmacist = false; // â¬…ï¸ VARIABLE DECLARED

// Â // Buyer Specific Data
// Â double _userWalletBalance = 0.0;
// Â List<String> _savedItems = []; // List of product IDs
// Â List<Address> _deliveryAddresses = [];

// Â // Vendor Specific Data
// Â bool _isVendor = false;
// Â String _vendorStatus = 'none';
// Â String? _businessName;
// Â int _totalProducts = 0;
// Â int _productsSold = 0;
// Â int _productsUnsold = 0;
// Â int _followersCount = 0;
// Â double _vendorWalletBalance = 0.0;
// Â double _appWalletBalance = 0.0;
// Â List<dynamic> _notifications = []; // Notifications are common but displayed differently

// Â // âœ… Store token in state so itâ€™s accessible across the widget
// Â String? _token;

// Â @override
// Â void initState() {
// Â Â super.initState();
// Â Â WidgetsBinding.instance.addObserver(this);
// Â Â _fetchUserData();
// Â }

// Â @override
// Â void dispose() {
// Â Â WidgetsBinding.instance.removeObserver(this);
// Â Â super.dispose();
// Â }

// Â @override
// Â void didChangeAppLifecycleState(AppLifecycleState state) {
// Â Â if (state == AppLifecycleState.resumed) {
// Â Â Â _fetchUserData(); // Refresh data when app resumes
// Â Â }
// Â }

// Â Future<void> _fetchUserData() async {
// Â Â setState(() {
// Â Â Â _isLoading = true;
// Â Â Â _errorMessage = null;
// Â Â });

// Â Â final SharedPreferences prefs = await SharedPreferences.getInstance();
// Â Â final String? token = prefs.getString('jwt_token');
// Â Â _token = token; // âœ… keep a copy in state

// Â Â if (token == null) {
// Â Â Â setState(() {
// Â Â Â Â _errorMessage = 'Authentication token not found. Please log in again.';
// Â Â Â Â _isLoading = false;
// Â Â Â });
// Â Â Â return;
// Â Â }

// Â Â try {
// Â Â Â final Uri url = Uri.parse('$baseUrl/api/auth/me');
// Â Â Â final response = await http.get(
// Â Â Â Â url,
// Â Â Â Â headers: <String, String>{
// Â Â Â Â Â 'Content-Type': 'application/json; charset=UTF-8',
// Â Â Â Â Â 'Authorization': 'Bearer $token',
// Â Â Â Â },
// Â Â Â );

// Â Â Â if (response.statusCode == 200) {
// Â Â Â Â final Map<String, dynamic> responseData = jsonDecode(response.body);
// Â Â Â Â setState(() {
// Â Â Â Â Â // Common User Data
// Â Â Â Â Â _firstName = responseData['firstName'] ?? '';
// Â Â Â Â Â _lastName = responseData['lastName'] ?? '';
// Â Â Â Â Â _email = responseData['email'] ?? '';
// Â Â Â Â Â _phoneNumber = responseData['phoneNumber'] ?? '';

// Â Â Â Â Â final String? fetchedProfilePicPath = responseData['profilePicUrl'];
// Â Â Â Â if (fetchedProfilePicPath != null && fetchedProfilePicPath.isNotEmpty) {
// Â Â Â Â Â if (fetchedProfilePicPath.startsWith('http')) {
// Â Â Â Â Â Â // If it's already a full URL (e.g., S3 link), use it as is.
// Â Â Â Â Â Â _profilePicUrl = fetchedProfilePicPath; 
// Â Â Â Â Â } else {
// Â Â Â Â Â Â // If it's a relative path, prepend the base URL.
// Â Â Â Â Â Â // Use the URL AS-IS; do NOT append a new timestamp.
// Â Â Â Â Â Â _profilePicUrl = '$baseUrl$fetchedProfilePicPath';
// Â Â Â Â Â }
// Â Â Â Â } else {
// Â Â Â Â Â _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User';
// Â Â Â Â }

// Â Â Â Â Â _isAdmin = responseData['isAdmin'] ?? false;
//           _isPharmacist = responseData['isPharmacist'] ?? false; // ğŸŒŸ PHARMACIST FIX APPLIED HERE

// Â Â Â Â Â // Buyer Specific Data
// Â Â Â Â Â _userWalletBalance = (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
// Â Â Â Â Â _savedItems = List<String>.from(responseData['savedItems'] ?? []);
// Â Â Â Â Â _deliveryAddresses = (responseData['deliveryAddresses'] as List?)
// Â Â Â Â Â Â Â ?.map((addrJson) => Address.fromJson(addrJson))
// Â Â Â Â Â Â Â .toList() ??
// Â Â Â Â Â Â Â [];

// Â Â Â Â Â // Vendor Specific Data
// Â Â Â Â Â _isVendor = responseData['isVendor'] ?? false;
// Â Â Â Â Â _vendorStatus = responseData['vendorStatus'] ?? 'none';
// Â Â Â Â Â _businessName = responseData['businessName'];
// Â Â Â Â Â _totalProducts = responseData['totalProducts'] ?? 0;
// Â Â Â Â Â _productsSold = responseData['productsSold'] ?? 0;
// Â Â Â Â Â _productsUnsold = responseData['productsUnsold'] ?? 0;
// Â Â Â Â Â _followersCount = responseData['followersCount'] ?? 0;
// Â Â Â Â Â _vendorWalletBalance = (responseData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
// Â Â Â Â Â _appWalletBalance = (responseData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
// Â Â Â Â Â _notifications = responseData['notifications'] ?? [];
// Â Â Â Â });
// Â Â Â } else {
// Â Â Â Â final responseData = jsonDecode(response.body);
// Â Â Â Â setState(() {
// Â Â Â Â Â _errorMessage = responseData['message'] ?? 'Failed to fetch user data.';
// Â Â Â Â });
// Â Â Â Â if (response.statusCode == 401) {
// Â Â Â Â Â prefs.remove('jwt_token');
// Â Â Â Â Â // Optionally navigate to login screen
// Â Â Â Â }
// Â Â Â }
// Â Â } catch (e) {
// Â Â Â setState(() {
// Â Â Â Â _errorMessage = 'An error occurred: $e. Please check your network connection.';
// Â Â Â });
// Â Â Â print('Fetch user data network error: $e');
// Â Â } finally {
// Â Â Â setState(() {
// Â Â Â Â _isLoading = false;
// Â Â Â });
// Â Â }
// Â }

// Â Future<void> _handleAccountDeletion() async {
// Â Â final bool confirm = await showDialog(
// Â Â Â context: context,
// Â Â Â builder: (context) => AlertDialog(
// Â Â Â Â title: const Text('Delete Account Permanently?'),
// Â Â Â Â content: const Text(
// Â Â Â Â Â Â 'This action is irreversible. All your data, including profile info, orders, and saved items, will be permanently deleted. Are you sure?'),
// Â Â Â Â actions: [
// Â Â Â Â Â TextButton(
// Â Â Â Â Â Â onPressed: () => Navigator.of(context).pop(false),
// Â Â Â Â Â Â child: const Text('Cancel'),
// Â Â Â Â Â ),
// Â Â Â Â Â TextButton(
// Â Â Â Â Â Â onPressed: () => Navigator.of(context).pop(true),
// Â Â Â Â Â Â child: const Text('Delete', style: TextStyle(color: Colors.red)),
// Â Â Â Â Â ),
// Â Â Â Â ],
// Â Â Â ),
// Â Â ) ?? false;

// Â Â if (confirm) {
// Â Â Â // Show loading indicator
// Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â const SnackBar(content: Text('Deleting account...'), duration: Duration(seconds: 2)),
// Â Â Â );

// Â Â Â final prefs = await SharedPreferences.getInstance();
// Â Â Â final token = prefs.getString('jwt_token');
// Â Â Â final url = Uri.parse('$baseUrl/api/auth/delete-account');

// Â Â Â try {
// Â Â Â Â final response = await http.delete(
// Â Â Â Â Â url,
// Â Â Â Â Â headers: {
// Â Â Â Â Â Â 'Content-Type': 'application/json',
// Â Â Â Â Â Â 'Authorization': 'Bearer $token',
// Â Â Â Â Â },
// Â Â Â Â );

// Â Â Â Â if (response.statusCode == 200) {
// Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Account successfully deleted.')));
// Â Â Â Â Â // Log out the user and navigate to the login screen
// Â Â Â Â Â await _handleLogout();
// Â Â Â Â } else {
// Â Â Â Â Â final responseBody = json.decode(response.body);
// Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(SnackBar(
// Â Â Â Â Â Â Â content: Text(
// Â Â Â Â Â Â Â Â Â responseBody['message'] ?? 'Failed to delete account. Please try again.')));
// Â Â Â Â }
// Â Â Â } catch (e) {
// Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â const SnackBar(content: Text('An error occurred. Check your network connection.')));
// Â Â Â Â print('Error during account deletion: $e');
// Â Â Â }
// Â Â }
// Â }

// Â Future<void> _handleLogout() async {
// Â Â final SharedPreferences prefs = await SharedPreferences.getInstance();
// Â Â await prefs.remove('jwt_token');

// Â Â widget.onLogout();
// Â }

// Â // einsteinenginefordevs@gmail.com
// Â // // A static or global function that does nothing, as it's not needed for logout navigation
// Â // static void _emptyOnLoginSuccess() {
// Â // Â // This function is intentionally left empty.
// Â // Â // It fulfills the `required` callback for LoginScreen when navigating to it during logout,
// Â // Â // but no actual login success action needs to occur from this navigation.
// Â // }

// Â @override
// Â Widget build(BuildContext context) {
// Â Â // Define your custom ColorScheme based on the provided colors
// Â Â final ColorScheme customColorScheme = const ColorScheme(
// Â Â Â primary: deepNavyBlue, // Dominant color for interactive elements, top app bar
// Â Â Â onPrimary: white, // Text and icons on top of primary color
// Â Â Â secondary: greenYellow, // Accent color for floating buttons, highlights
// Â Â Â onSecondary: deepNavyBlue, // Text and icons on top of secondary color
// Â Â Â surface: white, // Background for cards, sheets, elevated elements
// Â Â Â onSurface: deepNavyBlue, // Text and icons on top of surface color
// Â Â Â background: lightGray, // General screen background
// Â Â Â onBackground: deepNavyBlue, // Text and icons on top of background color
// Â Â Â error: Colors.red, // Error states
// Â Â Â onError: white, // Text and icons on top of error color
// Â Â Â brightness: Brightness.light, // Overall theme brightness
// Â Â );

// Â Â final color = customColorScheme; // Use your custom color scheme

// Â Â if (_isLoading) {
// Â Â Â return Scaffold(
// Â Â Â Â backgroundColor: color.background, // Use custom background
// Â Â Â Â body: Center(child: CircularProgressIndicator(color: color.primary)),
// Â Â Â );
// Â Â }

// Â Â if (_errorMessage != null) {
// Â Â Â return Scaffold(
// Â Â Â Â backgroundColor: color.background, // Use custom background
// Â Â Â Â body: Center(
// Â Â Â Â Â child: Padding(
// Â Â Â Â Â Â padding: const EdgeInsets.all(24.0),
// Â Â Â Â Â Â child: Column(
// Â Â Â Â Â Â Â mainAxisAlignment: MainAxisAlignment.center,
// Â Â Â Â Â Â Â children: [
// Â Â Â Â Â Â Â Â Icon(Icons.error_outline, color: color.error, size: 50),
// Â Â Â Â Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â Â Â Â Â Text(
// Â Â Â Â Â Â Â Â Â _errorMessage!,
// Â Â Â Â Â Â Â Â Â textAlign: TextAlign.center,
// Â Â Â Â Â Â Â Â Â style: TextStyle(color: color.error, fontSize: 16),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â const SizedBox(height: 20),
// Â Â Â Â Â Â Â Â ElevatedButton(
// Â Â Â Â Â Â Â Â Â onPressed: _fetchUserData,
// Â Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
// Â Â Â Â Â Â Â Â Â Â backgroundColor: color.primary,
// Â Â Â Â Â Â Â Â Â Â foregroundColor: color.onPrimary,
// Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â Â child: const Text('Retry'),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â ],
// Â Â Â Â Â Â ),
// Â Â Â Â Â ),
// Â Â Â Â ),
// Â Â Â );
// Â Â }

// Â Â return Scaffold(
// Â Â Â backgroundColor: color.background, // Main scaffold background
// Â Â Â body: SingleChildScrollView(
// Â Â Â Â padding: const EdgeInsets.all(16.0),
// Â Â Â Â child: Column(
// Â Â Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â Â Â children: [
// Â Â Â Â Â Â // ğŸ§‘ Profile Section
// Â Â Â Â Â Â _buildProfileSection(color),
// Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

// Â Â Â Â Â Â // ğŸ›ï¸ FOR BUYERS â€“ Tabs or List Items (Always shown, but content changes)
// Â Â Â Â Â Â _buildBuyerSection(color),
// Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

// Â Â Â Â Â Â // ğŸ›’ FOR VENDORS â€“ Show if user is a vendor
// Â Â Â Â Â Â if (_isVendor && _vendorStatus == 'approved')
// Â Â Â Â Â Â Â _buildVendorToolsSection(color)
// Â Â Â Â Â Â else
// Â Â Â Â Â Â Â _buildBecomeVendorCTA(color),
// Â Â Â Â Â Â Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

//             // ğŸŒŸ FOR PHARMACISTS â€“ Show if user is a pharmacist
//             if (_isPharmacist)
//               _buildPharmacistToolsSection(color),
//             if (_isPharmacist)
//               Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

// Â Â Â Â Â Â // âš™ï¸ COMMON TOOLS (For All Users)
// Â Â Â Â Â Â _buildCommonToolsSection(color),
// Â Â Â Â Â Â const SizedBox(height: 20),

// Â Â Â Â Â Â // Log Out Button
// Â Â Â Â Â Â SizedBox(
// Â Â Â Â Â Â Â width: double.infinity,
// Â Â Â Â Â Â Â child: ElevatedButton.icon(
// Â Â Â Â Â Â Â Â onPressed: _handleLogout,
// Â Â Â Â Â Â Â Â icon: Icon(Icons.logout, color: white), // White icon for contrast on red
// Â Â Â Â Â Â Â Â label: const Text('Log Out', style: TextStyle(color: white, fontSize: 18)), // White text for contrast
// Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
// Â Â Â Â Â Â Â Â Â backgroundColor: Colors.red.shade700, // Explicit red for logout action
// Â Â Â Â Â Â Â Â Â padding: const EdgeInsets.symmetric(vertical: 15),
// Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(
// Â Â Â Â Â Â Â Â Â Â borderRadius: BorderRadius.circular(12),
// Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â Â elevation: 5,
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â ),

// Â Â Â Â Â Â // --- ADD THIS NEW WIDGET HERE ---

// Â Â Â Â Â Â const SizedBox(height: 10), // Add a small space between the two buttons

// Â Â Â Â Â Â // Delete Account Button
// Â Â Â Â Â Â SizedBox(
// Â Â Â Â Â Â Â width: double.infinity,
// Â Â Â Â Â Â Â child: OutlinedButton.icon(
// Â Â Â Â Â Â Â Â onPressed: _handleAccountDeletion,
// Â Â Â Â Â Â Â Â icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
// Â Â Â Â Â Â Â Â label: Text('Delete Account', style: TextStyle(color: Colors.red.shade700, fontSize: 18)),
// Â Â Â Â Â Â Â Â style: OutlinedButton.styleFrom(
// Â Â Â Â Â Â Â Â Â padding: const EdgeInsets.symmetric(vertical: 15),
// Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(
// Â Â Â Â Â Â Â Â Â Â borderRadius: BorderRadius.circular(12),
// Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â Â side: BorderSide(color: Colors.red.shade700, width: 2),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â ),

// Â Â Â Â Â Â // --- Unique Ideas (Placeholders for now) ---
// Â Â Â Â Â Â const SizedBox(height: 40),
// Â Â Â Â Â Â Text(
// Â Â Â Â Â Â Â 'Unique Ideas (Coming Soon):',
// Â Â Â Â Â Â Â style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primary),
// Â Â Â Â Â Â ),
// Â Â Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'âœ… Buyerâ€“Seller Switch Toggle'),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ“¦ Live Order Map Tracker'),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ‰ Achievements/Badges'),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ’¬ Community Forum Link'),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ“ˆ Quick Stats Card (for Vendors)'),
// Â Â Â Â Â Â _buildComingSoonItem(color, 'ğŸ”” Smart Alerts'),
// Â Â Â Â Â Â const SizedBox(height: 40),
// Â Â Â Â Â ],
// Â Â Â Â ),
// Â Â Â ),
// Â Â );
// Â }

// Â // --- Helper Widgets for Sections ---

// Â Widget _buildProfileSection(ColorScheme color) {
// Â Â return Column(
// Â Â Â children: [
// Â Â Â Â Center(
// Â Â Â Â Â child: CircleAvatar(
// Â Â Â Â Â Â radius: 50,
// Â Â Â Â Â Â backgroundColor: color.surface, // Fallback background for avatar
// Â Â Â Â Â Â child: ClipOval(
// Â Â Â Â Â Â Â child: SizedBox.expand(
// Â Â Â Â Â Â Â Â child: CachedNetworkImage(
// Â Â Â Â Â Â Â Â Â imageUrl: _profilePicUrl,
// Â Â Â Â Â Â Â Â Â fit: BoxFit.cover,
// Â Â Â Â Â Â Â Â Â placeholder: (context, url) => Center(
// Â Â Â Â Â Â Â Â Â Â child: CircularProgressIndicator(color: color.primary),
// Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â Â errorWidget: (context, url, error) {
// Â Â Â Â Â Â Â Â Â Â return Icon(Icons.person, size: 60, color: color.onSurface.withOpacity(0.5));
// Â Â Â Â Â Â Â Â Â },
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â ),
// Â Â Â Â Â ),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â Text(
// Â Â Â Â Â '${_firstName} ${_lastName}',
// Â Â Â Â Â style: TextStyle(
// Â Â Â Â Â Â fontSize: 24,
// Â Â Â Â Â Â fontWeight: FontWeight.bold,
// Â Â Â Â Â Â color: color.onBackground, // Use onBackground for main text
// Â Â Â Â Â ),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 5),
// Â Â Â Â Text(
// Â Â Â Â Â _email,
// Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
// Â Â Â Â ),
// Â Â Â Â Text(
// Â Â Â Â Â _phoneNumber,
// Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 15),
// Â Â Â Â SizedBox(
// Â Â Â Â Â width: double.infinity,
// Â Â Â Â Â child: OutlinedButton.icon(
// Â Â Â Â Â Â onPressed: () async {
// Â Â Â Â Â Â Â final bool? result = await Navigator.of(context).push(
// Â Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const EditProfileScreen()),
// Â Â Â Â Â Â Â );
// Â Â Â Â Â Â Â if (result == true) {
// Â Â Â Â Â Â Â Â _fetchUserData(); // Refresh AccountScreen data after profile is updated
// Â Â Â Â Â Â Â }
// Â Â Â Â Â Â },
// Â Â Â Â Â Â icon: Icon(Icons.edit, color: color.primary),
// Â Â Â Â Â Â label: Text('Edit Profile', style: TextStyle(color: color.primary)),
// Â Â Â Â Â Â style: OutlinedButton.styleFrom(
// Â Â Â Â Â Â Â side: BorderSide(color: color.primary), // Border matches primary color
// Â Â Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
// Â Â Â Â Â Â ),
// Â Â Â Â Â ),
// Â Â Â Â ),
// Â Â Â ],
// Â Â );
// Â }

// Â Widget _buildBuyerSection(ColorScheme color) {
// Â Â return Column(
// Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â children: [
// Â Â Â Â Text(
// Â Â Â Â Â 'Buyer Tools',
// Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.shopping_bag_outlined,
// Â Â Â Â Â 'My Orders',
// Â Â Â Â Â 'Track all current & past orders',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.favorite_outline,
// Â Â Â Â Â 'Saved Items (Wishlist)',
// Â Â Â Â Â 'Easily revisit products you liked',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.account_balance_wallet_outlined,
// Â Â Â Â Â 'My Wallet / Payment Methods',
// Â Â Â Â Â 'Wallet balance: â‚¦${_userWalletBalance.toStringAsFixed(2)}',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const MyWalletScreen()),
// Â Â Â Â Â Â );
// Â Â Â Â Â Â _fetchUserData(); // Refresh account data after returning from wallet screen
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.location_on_outlined,
// Â Â Â Â Â 'Delivery Addresses',
// Â Â Â Â Â 'Manage your shipping locations',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const DeliveryAddressesScreen()),
// Â Â Â Â Â Â );
// Â Â Â Â Â Â _fetchUserData(); // Refresh account data after returning from addresses screen
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.star_outline,
// Â Â Â Â Â 'Reviews & Ratings',
// Â Â Â Â Â 'View products you reviewed',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(builder: (context) => const ReviewsRatingsScreen()),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.assignment_return_outlined,
// Â Â Â Â Â 'Returns & Disputes',
// Â Â Â Â Â 'View initiated return requests',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(
// Â Â Â Â Â Â Â Â builder: (context) => const DisputeListScreen(),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.help_outline,
// Â Â Â Â Â 'Help Center',
// Â Â Â Â Â 'FAQs, live chat, contact support',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(
// Â Â Â Â Â Â Â Â builder: (context) => const FAQScreen(),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â ],
// Â Â );
// Â }
// Â Widget _buildVendorToolsSection(ColorScheme color) {
// Â Â return Column(
// Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â children: [
// Â Â Â Â Text(
// Â Â Â Â Â 'Vendor Tools',
// Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.inventory_2_outlined,
// Â Â Â Â Â 'My Products',
// Â Â Â Â Â 'View/manage inventory (${_totalProducts} total, ${_productsUnsold} unsold)',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(
// Â Â Â Â Â Â Â Â builder: (context) => const VendorMyProductsScreen(),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.receipt_long_outlined,
// Â Â Â Â Â 'Orders Received',
// Â Â Â Â Â 'View buyer orders (${_productsSold} products sold)',
// Â Â Â Â Â Â Â () async {
// Â Â Â Â Â Â await Navigator.of(context).push(
// Â Â Â Â Â Â Â MaterialPageRoute(
// Â Â Â Â Â Â Â Â builder: (context) => const OrdersRecivedScreen(),
// Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.payments_outlined,
// Â Â Â Â Â 'Earnings Dashboard',
// Â Â Â Â Â 'Vendor Wallet: â‚¦${_vendorWalletBalance.toStringAsFixed(2)} | App Wallet: â‚¦${_appWalletBalance.toStringAsFixed(2)}',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Earnings Dashboard functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.campaign_outlined,
// Â Â Â Â Â 'Promotions & Ads',
// Â Â Â Â Â 'Promote a product, view ad performance',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Promotions & Ads functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.store_outlined,
// Â Â Â Â Â 'Store Profile',
// Â Â Â Â Â 'Edit store logo, bio, name',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Store Profile functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.message_outlined,
// Â Â Â Â Â 'Messages from Buyers',
// Â Â Â Â Â 'Buyer inquiries or complaints',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Messages from Buyers functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â ],
// Â Â );
// Â }

//   // ğŸŒŸ NEW HELPER METHOD FOR PHARMACIST DASHBOARD
//   Widget _buildPharmacistToolsSection(ColorScheme color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Pharmacist Tools',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
//         ),
//         const SizedBox(height: 10),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.local_pharmacy_outlined,
//           'Pharmacist Dashboard',
//           'Manage incoming prescription requests',
//           () {
//             Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (context) => const PharmacistDashboard(),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

// Â Widget _buildBecomeVendorCTA(ColorScheme color) {
// Â Â return Column(
// Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â children: [
// Â Â Â Â Text(
// Â Â Â Â Â 'Become a Vendor',
// Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â Card(
// Â Â Â Â Â elevation: 2,
// Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// Â Â Â Â Â color: color.surface, // Card background color
// Â Â Â Â Â child: Padding(
// Â Â Â Â Â Â padding: const EdgeInsets.all(16.0),
// Â Â Â Â Â Â child: Column(
// Â Â Â Â Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â Â Â Â Â children: [
// Â Â Â Â Â Â Â Â Text(
// Â Â Â Â Â Â Â Â Â 'Want to sell your products on NaijaGo?',
// Â Â Â Â Â Â Â Â Â style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color.onSurface),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â Â Â Â Â Text(
// Â Â Â Â Â Â Â Â Â 'Register as a vendor to list your products and manage your sales.',
// Â Â Â Â Â Â Â Â Â style: TextStyle(fontSize: 14, color: color.onSurface.withOpacity(0.7)),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â const SizedBox(height: 15),
// Â Â Â Â Â Â Â Â SizedBox(
// Â Â Â Â Â Â Â Â Â width: double.infinity,
// Â Â Â Â Â Â Â Â Â child: ElevatedButton.icon(
// Â Â Â Â Â Â Â Â Â Â onPressed: () {
// Â Â Â Â Â Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â Â Â Â Â Â const SnackBar(content: Text('Vendor Registration coming soon!')),
// Â Â Â Â Â Â Â Â Â Â Â );
// Â Â Â Â Â Â Â Â Â Â },
// Â Â Â Â Â Â Â Â Â Â icon: Icon(Icons.store_mall_directory_outlined, color: color.onPrimary),
// Â Â Â Â Â Â Â Â Â Â label: Text('Register as Vendor', style: TextStyle(color: color.onPrimary)),
// Â Â Â Â Â Â Â Â Â Â style: ElevatedButton.styleFrom(
// Â Â Â Â Â Â Â Â Â Â Â backgroundColor: color.primary,
// Â Â Â Â Â Â Â Â Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
// Â Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â Â ),
// Â Â Â Â Â Â Â ],
// Â Â Â Â Â Â ),
// Â Â Â Â Â ),
// Â Â Â Â ),
// Â Â Â ],
// Â Â );
// Â }

// Â Widget _buildCommonToolsSection(ColorScheme color) {
// Â Â return Column(
// Â Â Â crossAxisAlignment: CrossAxisAlignment.start,
// Â Â Â children: [
// Â Â Â Â Text(
// Â Â Â Â Â 'Common Tools',
// Â Â Â Â Â style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
// Â Â Â Â ),
// Â Â Â Â const SizedBox(height: 10),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.notifications_none,
// Â Â Â Â Â 'Notification Settings',
// Â Â Â Â Â 'Manage your notification preferences',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Notification Settings functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â // âœ… The Dark Mode Toggle now navigates to the SettingsScreen
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.brightness_4_outlined,
// Â Â Â Â Â 'Dark Mode Toggle',
// Â Â Â Â Â 'Switch between light and dark themes',
// Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('This Feature is Coming Soon')),
// Â Â Â Â Â Â );
// Â Â Â Â Â }
// Â Â Â Â Â // Â Â () {
// Â Â Â Â Â // Â // Navigate to the SettingsScreen class, which is defined in main.dart
// Â Â Â Â Â // Â Navigator.of(context).push(
// Â Â Â Â Â // Â Â MaterialPageRoute(builder: (context) => const SettingsScreen()),
// Â Â Â Â Â // Â );
// Â Â Â Â Â // },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.language_outlined,
// Â Â Â Â Â 'Language & Region',
// Â Â Â Â Â 'Change app language and region settings',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Language & Region functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â Â _buildAccountListItem(
// Â Â Â Â Â context,
// Â Â Â Â Â color,
// Â Â Â Â Â Icons.share_outlined,
// Â Â Â Â Â 'Invite a Friend',
// Â Â Â Â Â 'Share NaijaGo with your friends',
// Â Â Â Â Â Â Â () {
// Â Â Â Â Â Â ScaffoldMessenger.of(context).showSnackBar(
// Â Â Â Â Â Â Â const SnackBar(content: Text('Invite a Friend functionality coming soon!')),
// Â Â Â Â Â Â );
// Â Â Â Â Â },
// Â Â Â Â ),
// Â Â Â ],
// Â Â );
// Â }

// Â // Helper for consistent list item styling
// Â Widget _buildAccountListItem(BuildContext context, ColorScheme color, IconData icon, String title, String subtitle, VoidCallback onTap) {
// Â Â return Card(
// Â Â Â elevation: 2,
// Â Â Â shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
// Â Â Â margin: const EdgeInsets.symmetric(vertical: 6.0),
// Â Â Â color: color.surface, // Card background color
// Â Â Â child: ListTile(
// Â Â Â Â leading: Icon(icon, color: color.primary, size: 28), // Icon color
// Â Â Â Â title: Text(title, style: TextStyle(color: color.onSurface, fontWeight: FontWeight.w600)), // Title text color
// Â Â Â Â subtitle: Text(subtitle, style: TextStyle(color: color.onSurface.withOpacity(0.7))), // Subtitle text color
// Â Â Â Â trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color.onSurface.withOpacity(0.5)), // Arrow icon color
// Â Â Â Â onTap: onTap,
// Â Â Â ),
// Â Â );
// Â }

// Â Widget _buildComingSoonItem(ColorScheme color, String text) {
// Â Â return Padding(
// Â Â Â padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
// Â Â Â child: Row(
// Â Â Â Â children: [
// Â Â Â Â Â Icon(Icons.check_circle_outline, size: 20, color: greenYellow), // Checkmark icon color
// Â Â Â Â Â const SizedBox(width: 10),
// Â Â Â Â Â Expanded(
// Â Â Â Â Â Â child: Text(
// Â Â Â Â Â Â Â text,
// Â Â Â Â Â Â Â style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.8)), // Text color
// Â Â Â Â Â Â ),
// Â Â Â Â Â ),
// Â Â Â Â ],
// Â Â Â ),
// Â Â );
// Â }
// }




































// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // âœ… Added
// import '../../constants.dart';
// // Import your main.dart file to access the ThemeChanger and SettingsScreen classes
// import '../../main.dart';
// // import '../../admin/screens/admin_panel_screen.dart'; // Import for Admin Panel
// import '../../models/address.dart'; // Import Address model
// import '../../auth/screens/login_screen.dart'; // Import LoginScreen
// import 'my_orders_screen.dart'; // Import MyOrdersScreen
// import 'saved_items_screen.dart'; // Import SavedItemsScreen
// import 'delivery_addresses_screen.dart'; // Import DeliveryAddressesScreen
// import 'edit_profile_screen.dart'; // Import EditProfileScreen
// import 'my_wallet_screen.dart'; // Import MyWalletScreen
// import 'reviews_ratings_screen.dart'; // NEW: Import ReviewsRatingsScreen
// import 'create_dispute_screen.dart';
// import 'dispute_list_screen.dart';
// import 'faq_screen.dart';
// import 'vendor_my_products_screen.dart';
// import '../../screens/vendor/orders_recived_screen.dart.dart';
// import 'pharmacist_dashboard.dart';

// // Define your color constants (consistent with vendor registration)
// const Color deepNavyBlue = Color(0xFF03024C);
// const Color greenYellow = Color(0xFFADFF2F);
// const Color white = Colors.white;
// const Color lightGray = Color(0xFFF5F5F5); // Adding a light gray for subtle backgrounds if needed

// class AccountScreen extends StatefulWidget {
//   final VoidCallback onLogout;

//   const AccountScreen({super.key, required this.onLogout});

//   @override
//   State<AccountScreen> createState() => _AccountScreenState();
// }

// class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
//   bool _isLoading = true;
//   String? _errorMessage;

//   // User Profile Data
//   String _firstName = '';
//   String _lastName = '';
//   String _email = '';
//   String _phoneNumber = '';
//   String _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User'; // Default placeholder
//   bool _isAdmin = false;
//   bool _isPharmacist = false; // â¬…ï¸ ADD THIS VARIABLE

//   // Buyer Specific Data
//   double _userWalletBalance = 0.0;
//   List<String> _savedItems = []; // List of product IDs
//   List<Address> _deliveryAddresses = [];

//   // Vendor Specific Data
//   bool _isVendor = false;
//   String _vendorStatus = 'none';
//   String? _businessName;
//   int _totalProducts = 0;
//   int _productsSold = 0;
//   int _productsUnsold = 0;
//   int _followersCount = 0;
//   double _vendorWalletBalance = 0.0;
//   double _appWalletBalance = 0.0;
//   List<dynamic> _notifications = []; // Notifications are common but displayed differently

//   // âœ… Store token in state so itâ€™s accessible across the widget
//   String? _token;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _fetchUserData();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _fetchUserData(); // Refresh data when app resumes
//     }
//   }

//   Future<void> _fetchUserData() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');
//     _token = token; // âœ… keep a copy in state

//     if (token == null) {
//       setState(() {
//         _errorMessage = 'Authentication token not found. Please log in again.';
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final Uri url = Uri.parse('$baseUrl/api/auth/me');
//       final response = await http.get(
//         url,
//         headers: <String, String>{
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         setState(() {
//           // Common User Data
//           _firstName = responseData['firstName'] ?? '';
//           _lastName = responseData['lastName'] ?? '';
//           _email = responseData['email'] ?? '';
//           _phoneNumber = responseData['phoneNumber'] ?? '';

//           final String? fetchedProfilePicPath = responseData['profilePicUrl'];
//         if (fetchedProfilePicPath != null && fetchedProfilePicPath.isNotEmpty) {
//           if (fetchedProfilePicPath.startsWith('http')) {
//             // If it's already a full URL (e.g., S3 link), use it as is.
//             _profilePicUrl = fetchedProfilePicPath; 
//           } else {
//             // If it's a relative path, prepend the base URL.
//             // Use the URL AS-IS; do NOT append a new timestamp.
//             _profilePicUrl = '$baseUrl$fetchedProfilePicPath';
//           }
//         } else {
//           _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User';
//         }

//           _isAdmin = responseData['isAdmin'] ?? false;

//           // Buyer Specific Data
//           _userWalletBalance = (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
//           _savedItems = List<String>.from(responseData['savedItems'] ?? []);
//           _deliveryAddresses = (responseData['deliveryAddresses'] as List?)
//               ?.map((addrJson) => Address.fromJson(addrJson))
//               .toList() ??
//               [];

//           // Vendor Specific Data
//           _isVendor = responseData['isVendor'] ?? false;
//           _vendorStatus = responseData['vendorStatus'] ?? 'none';
//           _businessName = responseData['businessName'];
//           _totalProducts = responseData['totalProducts'] ?? 0;
//           _productsSold = responseData['productsSold'] ?? 0;
//           _productsUnsold = responseData['productsUnsold'] ?? 0;
//           _followersCount = responseData['followersCount'] ?? 0;
//           _vendorWalletBalance = (responseData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
//           _appWalletBalance = (responseData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
//           _notifications = responseData['notifications'] ?? [];
//         });
//       } else {
//         final responseData = jsonDecode(response.body);
//         setState(() {
//           _errorMessage = responseData['message'] ?? 'Failed to fetch user data.';
//         });
//         if (response.statusCode == 401) {
//           prefs.remove('jwt_token');
//           // Optionally navigate to login screen
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An error occurred: $e. Please check your network connection.';
//       });
//       print('Fetch user data network error: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _handleAccountDeletion() async {
//     final bool confirm = await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Account Permanently?'),
//         content: const Text(
//             'This action is irreversible. All your data, including profile info, orders, and saved items, will be permanently deleted. Are you sure?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: const Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     ) ?? false;

//     if (confirm) {
//       // Show loading indicator
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Deleting account...'), duration: Duration(seconds: 2)),
//       );

//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('jwt_token');
//       final url = Uri.parse('$baseUrl/api/auth/delete-account');

//       try {
//         final response = await http.delete(
//           url,
//           headers: {
//             'Content-Type': 'application/json',
//             'Authorization': 'Bearer $token',
//           },
//         );

//         if (response.statusCode == 200) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Account successfully deleted.')));
//           // Log out the user and navigate to the login screen
//           await _handleLogout();
//         } else {
//           final responseBody = json.decode(response.body);
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               content: Text(
//                   responseBody['message'] ?? 'Failed to delete account. Please try again.')));
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('An error occurred. Check your network connection.')));
//         print('Error during account deletion: $e');
//       }
//     }
//   }

//   Future<void> _handleLogout() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.remove('jwt_token');

//     widget.onLogout();
//   }

//   // einsteinenginefordevs@gmail.com
//   // // A static or global function that does nothing, as it's not needed for logout navigation
//   // static void _emptyOnLoginSuccess() {
//   // Â // This function is intentionally left empty.
//   // Â // It fulfills the `required` callback for LoginScreen when navigating to it during logout,
//   // Â // but no actual login success action needs to occur from this navigation.
//   // }

//   @override
//   Widget build(BuildContext context) {
//     // Define your custom ColorScheme based on the provided colors
//     final ColorScheme customColorScheme = const ColorScheme(
//       primary: deepNavyBlue, // Dominant color for interactive elements, top app bar
//       onPrimary: white, // Text and icons on top of primary color
//       secondary: greenYellow, // Accent color for floating buttons, highlights
//       onSecondary: deepNavyBlue, // Text and icons on top of secondary color
//       surface: white, // Background for cards, sheets, elevated elements
//       onSurface: deepNavyBlue, // Text and icons on top of surface color
//       background: lightGray, // General screen background
//       onBackground: deepNavyBlue, // Text and icons on top of background color
//       error: Colors.red, // Error states
//       onError: white, // Text and icons on top of error color
//       brightness: Brightness.light, // Overall theme brightness
//     );

//     final color = customColorScheme; // Use your custom color scheme

//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: color.background, // Use custom background
//         body: Center(child: CircularProgressIndicator(color: color.primary)),
//       );
//     }

//     if (_errorMessage != null) {
//       return Scaffold(
//         backgroundColor: color.background, // Use custom background
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.error_outline, color: color.error, size: 50),
//                 const SizedBox(height: 10),
//                 Text(
//                   _errorMessage!,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: color.error, fontSize: 16),
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _fetchUserData,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: color.primary,
//                     foregroundColor: color.onPrimary,
//                   ),
//                   child: const Text('Retry'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: color.background, // Main scaffold background
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ğŸ§‘ Profile Section
//             _buildProfileSection(color),
//             Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

//             // ğŸ›ï¸ FOR BUYERS â€“ Tabs or List Items (Always shown, but content changes)
//             _buildBuyerSection(color),
//             Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

//             // ğŸ›’ FOR VENDORS â€“ Show if user is a vendor
//             if (_isVendor && _vendorStatus == 'approved')
//               _buildVendorToolsSection(color)
//             else
//               _buildBecomeVendorCTA(color),
//             Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

//             // âš™ï¸ COMMON TOOLS (For All Users)
//             _buildCommonToolsSection(color),
//             const SizedBox(height: 20),

//             // Log Out Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: _handleLogout,
//                 icon: Icon(Icons.logout, color: white), // White icon for contrast on red
//                 label: const Text('Log Out', style: TextStyle(color: white, fontSize: 18)), // White text for contrast
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red.shade700, // Explicit red for logout action
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   elevation: 5,
//                 ),
//               ),
//             ),

//             // --- ADD THIS NEW WIDGET HERE ---

//             const SizedBox(height: 10), // Add a small space between the two buttons

//             // Delete Account Button
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: _handleAccountDeletion,
//                 icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
//                 label: Text('Delete Account', style: TextStyle(color: Colors.red.shade700, fontSize: 18)),
//                 style: OutlinedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   side: BorderSide(color: Colors.red.shade700, width: 2),
//                 ),
//               ),
//             ),

//             // --- Unique Ideas (Placeholders for now) ---
//             const SizedBox(height: 40),
//             Text(
//               'Unique Ideas (Coming Soon):',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primary),
//             ),
//             const SizedBox(height: 10),
//             _buildComingSoonItem(color, 'âœ… Buyerâ€“Seller Switch Toggle'),
//             _buildComingSoonItem(color, 'ğŸ“¦ Live Order Map Tracker'),
//             _buildComingSoonItem(color, 'ğŸ‰ Achievements/Badges'),
//             _buildComingSoonItem(color, 'ğŸ’¬ Community Forum Link'),
//             _buildComingSoonItem(color, 'ğŸ“ˆ Quick Stats Card (for Vendors)'),
//             _buildComingSoonItem(color, 'ğŸ”” Smart Alerts'),
//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- Helper Widgets for Sections ---

//   Widget _buildProfileSection(ColorScheme color) {
//     return Column(
//       children: [
//         Center(
//           child: CircleAvatar(
//             radius: 50,
//             backgroundColor: color.surface, // Fallback background for avatar
//             child: ClipOval(
//               child: SizedBox.expand(
//                 child: CachedNetworkImage(
//                   imageUrl: _profilePicUrl,
//                   fit: BoxFit.cover,
//                   placeholder: (context, url) => Center(
//                     child: CircularProgressIndicator(color: color.primary),
//                   ),
//                   errorWidget: (context, url, error) {
//                     return Icon(Icons.person, size: 60, color: color.onSurface.withOpacity(0.5));
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 10),
//         Text(
//           '${_firstName} ${_lastName}',
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: color.onBackground, // Use onBackground for main text
//           ),
//         ),
//         const SizedBox(height: 5),
//         Text(
//           _email,
//           style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
//         ),
//         Text(
//           _phoneNumber,
//           style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
//         ),
//         const SizedBox(height: 15),
//         SizedBox(
//           width: double.infinity,
//           child: OutlinedButton.icon(
//             onPressed: () async {
//               final bool? result = await Navigator.of(context).push(
//                 MaterialPageRoute(builder: (context) => const EditProfileScreen()),
//               );
//               if (result == true) {
//                 _fetchUserData(); // Refresh AccountScreen data after profile is updated
//               }
//             },
//             icon: Icon(Icons.edit, color: color.primary),
//             label: Text('Edit Profile', style: TextStyle(color: color.primary)),
//             style: OutlinedButton.styleFrom(
//               side: BorderSide(color: color.primary), // Border matches primary color
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildBuyerSection(ColorScheme color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Buyer Tools',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
//         ),
//         const SizedBox(height: 10),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.shopping_bag_outlined,
//           'My Orders',
//           'Track all current & past orders',
//               () {
//             Navigator.of(context).push(
//               MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.favorite_outline,
//           'Saved Items (Wishlist)',
//           'Easily revisit products you liked',
//               () {
//             Navigator.of(context).push(
//               MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.account_balance_wallet_outlined,
//           'My Wallet / Payment Methods',
//           'Wallet balance: â‚¦${_userWalletBalance.toStringAsFixed(2)}',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(builder: (context) => const MyWalletScreen()),
//             );
//             _fetchUserData(); // Refresh account data after returning from wallet screen
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.location_on_outlined,
//           'Delivery Addresses',
//           'Manage your shipping locations',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(builder: (context) => const DeliveryAddressesScreen()),
//             );
//             _fetchUserData(); // Refresh account data after returning from addresses screen
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.star_outline,
//           'Reviews & Ratings',
//           'View products you reviewed',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(builder: (context) => const ReviewsRatingsScreen()),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.assignment_return_outlined,
//           'Returns & Disputes',
//           'View initiated return requests',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (context) => const DisputeListScreen(),
//               ),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.help_outline,
//           'Help Center',
//           'FAQs, live chat, contact support',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (context) => const FAQScreen(),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//   Widget _buildVendorToolsSection(ColorScheme color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Vendor Tools',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
//         ),
//         const SizedBox(height: 10),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.inventory_2_outlined,
//           'My Products',
//           'View/manage inventory (${_totalProducts} total, ${_productsUnsold} unsold)',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (context) => const VendorMyProductsScreen(),
//               ),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.receipt_long_outlined,
//           'Orders Received',
//           'View buyer orders (${_productsSold} products sold)',
//               () async {
//             await Navigator.of(context).push(
//               MaterialPageRoute(
//                 builder: (context) => const OrdersRecivedScreen(),
//               ),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.payments_outlined,
//           'Earnings Dashboard',
//           'Vendor Wallet: â‚¦${_vendorWalletBalance.toStringAsFixed(2)} | App Wallet: â‚¦${_appWalletBalance.toStringAsFixed(2)}',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Earnings Dashboard functionality coming soon!')),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.campaign_outlined,
//           'Promotions & Ads',
//           'Promote a product, view ad performance',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Promotions & Ads functionality coming soon!')),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.store_outlined,
//           'Store Profile',
//           'Edit store logo, bio, name',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Store Profile functionality coming soon!')),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.message_outlined,
//           'Messages from Buyers',
//           'Buyer inquiries or complaints',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Messages from Buyers functionality coming soon!')),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildBecomeVendorCTA(ColorScheme color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Become a Vendor',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
//         ),
//         const SizedBox(height: 10),
//         Card(
//           elevation: 2,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           color: color.surface, // Card background color
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Want to sell your products on NaijaGo?',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color.onSurface),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   'Register as a vendor to list your products and manage your sales.',
//                   style: TextStyle(fontSize: 14, color: color.onSurface.withOpacity(0.7)),
//                 ),
//                 const SizedBox(height: 15),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton.icon(
//                     onPressed: () {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Vendor Registration coming soon!')),
//                       );
//                     },
//                     icon: Icon(Icons.store_mall_directory_outlined, color: color.onPrimary),
//                     label: Text('Register as Vendor', style: TextStyle(color: color.onPrimary)),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color.primary,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildCommonToolsSection(ColorScheme color) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Common Tools',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
//         ),
//         const SizedBox(height: 10),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.notifications_none,
//           'Notification Settings',
//           'Manage your notification preferences',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Notification Settings functionality coming soon!')),
//             );
//           },
//         ),
//         // âœ… The Dark Mode Toggle now navigates to the SettingsScreen
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.brightness_4_outlined,
//           'Dark Mode Toggle',
//           'Switch between light and dark themes',
//           () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('This Feature is Coming Soon')),
//             );
//           }
//           //     () {
//           //   // Navigate to the SettingsScreen class, which is defined in main.dart
//           //   Navigator.of(context).push(
//           //     MaterialPageRoute(builder: (context) => const SettingsScreen()),
//           //   );
//           // },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.language_outlined,
//           'Language & Region',
//           'Change app language and region settings',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Language & Region functionality coming soon!')),
//             );
//           },
//         ),
//         _buildAccountListItem(
//           context,
//           color,
//           Icons.share_outlined,
//           'Invite a Friend',
//           'Share NaijaGo with your friends',
//               () {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Invite a Friend functionality coming soon!')),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   // Helper for consistent list item styling
//   Widget _buildAccountListItem(BuildContext context, ColorScheme color, IconData icon, String title, String subtitle, VoidCallback onTap) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       margin: const EdgeInsets.symmetric(vertical: 6.0),
//       color: color.surface, // Card background color
//       child: ListTile(
//         leading: Icon(icon, color: color.primary, size: 28), // Icon color
//         title: Text(title, style: TextStyle(color: color.onSurface, fontWeight: FontWeight.w600)), // Title text color
//         subtitle: Text(subtitle, style: TextStyle(color: color.onSurface.withOpacity(0.7))), // Subtitle text color
//         trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color.onSurface.withOpacity(0.5)), // Arrow icon color
//         onTap: onTap,
//       ),
//     );
//   }

//   Widget _buildComingSoonItem(ColorScheme color, String text) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
//       child: Row(
//         children: [
//           Icon(Icons.check_circle_outline, size: 20, color: greenYellow), // Checkmark icon color
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               text,
//               style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.8)), // Text color
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
