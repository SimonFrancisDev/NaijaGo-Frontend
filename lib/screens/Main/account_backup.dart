import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Added
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
import 'pharmacist_dashboard.dart'; // ✅ Import PharmacistDashboard

// Define your color constants (consistent with vendor registration)
const Color deepNavyBlue = Color(0xFF03024C);
const Color greenYellow = Color(0xFFADFF2F);
const Color white = Colors.white;
const Color lightGray = Color(0xFFF5F5F5); // Adding a light gray for subtle backgrounds if needed

class AccountScreen extends StatefulWidget {
� final VoidCallback onLogout;

� const AccountScreen({super.key, required this.onLogout});

� @override
� State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
� bool _isLoading = true;
� String? _errorMessage;

� // User Profile Data
� String _firstName = '';
� String _lastName = '';
� String _email = '';
� String _phoneNumber = '';
� String _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User'; // Default placeholder
� bool _isAdmin = false;
� bool _isPharmacist = false; // ⬅️ VARIABLE DECLARED

� // Buyer Specific Data
� double _userWalletBalance = 0.0;
� List<String> _savedItems = []; // List of product IDs
� List<Address> _deliveryAddresses = [];

� // Vendor Specific Data
� bool _isVendor = false;
� String _vendorStatus = 'none';
� String? _businessName;
� int _totalProducts = 0;
� int _productsSold = 0;
� int _productsUnsold = 0;
� int _followersCount = 0;
� double _vendorWalletBalance = 0.0;
� double _appWalletBalance = 0.0;
� List<dynamic> _notifications = []; // Notifications are common but displayed differently

� // ✅ Store token in state so it’s accessible across the widget
� String? _token;

� @override
� void initState() {
� � super.initState();
� � WidgetsBinding.instance.addObserver(this);
� � _fetchUserData();
� }

� @override
� void dispose() {
� � WidgetsBinding.instance.removeObserver(this);
� � super.dispose();
� }

� @override
� void didChangeAppLifecycleState(AppLifecycleState state) {
� � if (state == AppLifecycleState.resumed) {
� � � _fetchUserData(); // Refresh data when app resumes
� � }
� }

� Future<void> _fetchUserData() async {
� � setState(() {
� � � _isLoading = true;
� � � _errorMessage = null;
� � });

� � final SharedPreferences prefs = await SharedPreferences.getInstance();
� � final String? token = prefs.getString('jwt_token');
� � _token = token; // ✅ keep a copy in state

� � if (token == null) {
� � � setState(() {
� � � � _errorMessage = 'Authentication token not found. Please log in again.';
� � � � _isLoading = false;
� � � });
� � � return;
� � }

� � try {
� � � final Uri url = Uri.parse('$baseUrl/api/auth/me');
� � � final response = await http.get(
� � � � url,
� � � � headers: <String, String>{
� � � � � 'Content-Type': 'application/json; charset=UTF-8',
� � � � � 'Authorization': 'Bearer $token',
� � � � },
� � � );

� � � if (response.statusCode == 200) {
� � � � final Map<String, dynamic> responseData = jsonDecode(response.body);
� � � � setState(() {
� � � � � // Common User Data
� � � � � _firstName = responseData['firstName'] ?? '';
� � � � � _lastName = responseData['lastName'] ?? '';
� � � � � _email = responseData['email'] ?? '';
� � � � � _phoneNumber = responseData['phoneNumber'] ?? '';

� � � � � final String? fetchedProfilePicPath = responseData['profilePicUrl'];
� � � � if (fetchedProfilePicPath != null && fetchedProfilePicPath.isNotEmpty) {
� � � � � if (fetchedProfilePicPath.startsWith('http')) {
� � � � � � // If it's already a full URL (e.g., S3 link), use it as is.
� � � � � � _profilePicUrl = fetchedProfilePicPath; 
� � � � � } else {
� � � � � � // If it's a relative path, prepend the base URL.
� � � � � � // Use the URL AS-IS; do NOT append a new timestamp.
� � � � � � _profilePicUrl = '$baseUrl$fetchedProfilePicPath';
� � � � � }
� � � � } else {
� � � � � _profilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User';
� � � � }

� � � � � _isAdmin = responseData['isAdmin'] ?? false;
� � � � � _isPharmacist = responseData['isPharmacist'] ?? false; // 🌟 PHARMACIST FIX APPLIED HERE

� � � � � // Buyer Specific Data
� � � � � _userWalletBalance = (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
� � � � � _savedItems = List<String>.from(responseData['savedItems'] ?? []);
� � � � � _deliveryAddresses = (responseData['deliveryAddresses'] as List?)
� � � � � � � ?.map((addrJson) => Address.fromJson(addrJson))
� � � � � � � .toList() ??
� � � � � � � [];

� � � � � // Vendor Specific Data
� � � � � _isVendor = responseData['isVendor'] ?? false;
� � � � � _vendorStatus = responseData['vendorStatus'] ?? 'none';
� � � � � _businessName = responseData['businessName'];
� � � � � _totalProducts = responseData['totalProducts'] ?? 0;
� � � � � _productsSold = responseData['productsSold'] ?? 0;
� � � � � _productsUnsold = responseData['productsUnsold'] ?? 0;
� � � � � _followersCount = responseData['followersCount'] ?? 0;
� � � � � _vendorWalletBalance = (responseData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
� � � � � _appWalletBalance = (responseData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
� � � � � _notifications = responseData['notifications'] ?? [];
� � � � });
� � � } else {
� � � � final responseData = jsonDecode(response.body);
� � � � setState(() {
� � � � � _errorMessage = responseData['message'] ?? 'Failed to fetch user data.';
� � � � });
� � � � if (response.statusCode == 401) {
� � � � � prefs.remove('jwt_token');
� � � � � // Optionally navigate to login screen
� � � � }
� � � }
� � } catch (e) {
� � � setState(() {
� � � � _errorMessage = 'An error occurred: $e. Please check your network connection.';
� � � });
� � � print('Fetch user data network error: $e');
� � } finally {
� � � setState(() {
� � � � _isLoading = false;
� � � });
� � }
� }

� Future<void> _handleAccountDeletion() async {
� � final bool confirm = await showDialog(
� � � context: context,
� � � builder: (context) => AlertDialog(
� � � � title: const Text('Delete Account Permanently?'),
� � � � content: const Text(
� � � � � � 'This action is irreversible. All your data, including profile info, orders, and saved items, will be permanently deleted. Are you sure?'),
� � � � actions: [
� � � � � TextButton(
� � � � � � onPressed: () => Navigator.of(context).pop(false),
� � � � � � child: const Text('Cancel'),
� � � � � ),
� � � � � TextButton(
� � � � � � onPressed: () => Navigator.of(context).pop(true),
� � � � � � child: const Text('Delete', style: TextStyle(color: Colors.red)),
� � � � � ),
� � � � ],
� � � ),
� � ) ?? false;

� � if (confirm) {
� � � // Show loading indicator
� � � ScaffoldMessenger.of(context).showSnackBar(
� � � � const SnackBar(content: Text('Deleting account...'), duration: Duration(seconds: 2)),
� � � );


� � � final prefs = await SharedPreferences.getInstance();
� � � final token = prefs.getString('jwt_token');
� � � final url = Uri.parse('$baseUrl/api/auth/delete-account');

� � � try {
� � � � final response = await http.delete(
� � � � � url,
� � � � � headers: {
� � � � � � 'Content-Type': 'application/json',
� � � � � � 'Authorization': 'Bearer $token',
� � � � � },
� � � � );

� � � � if (response.statusCode == 200) {
� � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Account successfully deleted.')));
� � � � � // Log out the user and navigate to the login screen
� � � � � await _handleLogout();
� � � � } else {
� � � � � final responseBody = json.decode(response.body);
� � � � � ScaffoldMessenger.of(context).showSnackBar(SnackBar(
� � � � � � � content: Text(
� � � � � � � � � responseBody['message'] ?? 'Failed to delete account. Please try again.')));
� � � � }
� � � } catch (e) {
� � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � const SnackBar(content: Text('An error occurred. Check your network connection.')));
� � � � print('Error during account deletion: $e');
� � � }
� � }
� }

� Future<void> _handleLogout() async {
� � final SharedPreferences prefs = await SharedPreferences.getInstance();
� � await prefs.remove('jwt_token');

� � widget.onLogout();
� }

� // einsteinenginefordevs@gmail.com
� // // A static or global function that does nothing, as it's not needed for logout navigation
� // static void _emptyOnLoginSuccess() {
� // � // This function is intentionally left empty.
� // � // It fulfills the `required` callback for LoginScreen when navigating to it during logout,
� // � // but no actual login success action needs to occur from this navigation.
� // }

� @override
� Widget build(BuildContext context) {
� � // Define your custom ColorScheme based on the provided colors
� � final ColorScheme customColorScheme = const ColorScheme(
� � � primary: deepNavyBlue, // Dominant color for interactive elements, top app bar
� � � onPrimary: white, // Text and icons on top of primary color
� � � secondary: greenYellow, // Accent color for floating buttons, highlights
� � � onSecondary: deepNavyBlue, // Text and icons on top of secondary color
� � � surface: white, // Background for cards, sheets, elevated elements
� � � onSurface: deepNavyBlue, // Text and icons on top of surface color
� � � background: lightGray, // General screen background
� � � onBackground: deepNavyBlue, // Text and icons on top of background color
� � � error: Colors.red, // Error states
� � � onError: white, // Text and icons on top of error color
� � � brightness: Brightness.light, // Overall theme brightness
� � );

� � final color = customColorScheme; // Use your custom color scheme

� � if (_isLoading) {
� � � return Scaffold(
� � � � backgroundColor: color.background, // Use custom background
� � � � body: Center(child: CircularProgressIndicator(color: color.primary)),
� � � );
� � }

� � if (_errorMessage != null) {
� � � return Scaffold(
� � � � backgroundColor: color.background, // Use custom background
� � � � body: Center(
� � � � � child: Padding(
� � � � � � padding: const EdgeInsets.all(24.0),
� � � � � � child: Column(
� � � � � � � mainAxisAlignment: MainAxisAlignment.center,
� � � � � � � children: [
� � � � � � � � Icon(Icons.error_outline, color: color.error, size: 50),
� � � � � � � � const SizedBox(height: 10),
� � � � � � � � Text(
� � � � � � � � � _errorMessage!,
� � � � � � � � � textAlign: TextAlign.center,
� � � � � � � � � style: TextStyle(color: color.error, fontSize: 16),
� � � � � � � � ),
� � � � � � � � const SizedBox(height: 20),
� � � � � � � � ElevatedButton(
� � � � � � � � � onPressed: _fetchUserData,
� � � � � � � � � style: ElevatedButton.styleFrom(
� � � � � � � � � � backgroundColor: color.primary,
� � � � � � � � � � foregroundColor: color.onPrimary,
� � � � � � � � � ),
� � � � � � � � � child: const Text('Retry'),
� � � � � � � � ),
� � � � � � � ],
� � � � � � ),
� � � � � ),
� � � � ),
� � � );
� � }

� � return Scaffold(
� � � backgroundColor: color.background, // Main scaffold background
� � � body: SingleChildScrollView(
� � � � padding: const EdgeInsets.all(16.0),
� � � � child: Column(
� � � � � crossAxisAlignment: CrossAxisAlignment.start,
� � � � � children: [
� � � � � � // 🧑 Profile Section
� � � � � � _buildProfileSection(color),
� � � � � � Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

� � � � � � // 🛍️ FOR BUYERS – Tabs or List Items (Always shown, but content changes)
� � � � � � _buildBuyerSection(color),
� � � � � � Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

� � � � � � // 🛒 FOR VENDORS – Show if user is a vendor
� � � � � � if (_isVendor && _vendorStatus == 'approved')
� � � � � � � _buildVendorToolsSection(color)
� � � � � � else
� � � � � � � _buildBecomeVendorCTA(color),
� � � � � � Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

� � � � � � // 🌟 FOR PHARMACISTS – Show if user is a pharmacist
� � � � � � if (_isPharmacist)
� � � � � � � _buildPharmacistToolsSection(color),
� � � � � � if (_isPharmacist)
� � � � � � � Divider(height: 30, thickness: 1, color: color.onBackground.withOpacity(0.2)),

� � � � � � // ⚙️ COMMON TOOLS (For All Users)
� � � � � � _buildCommonToolsSection(color),
� � � � � � const SizedBox(height: 20),

� � � � � � // Log Out Button
� � � � � � SizedBox(
� � � � � � � width: double.infinity,
� � � � � � � child: ElevatedButton.icon(
� � � � � � � � onPressed: _handleLogout,
� � � � � � � � icon: Icon(Icons.logout, color: white), // White icon for contrast on red
� � � � � � � � label: const Text('Log Out', style: TextStyle(color: white, fontSize: 18)), // White text for contrast
� � � � � � � � style: ElevatedButton.styleFrom(
� � � � � � � � � backgroundColor: Colors.red.shade700, // Explicit red for logout action
� � � � � � � � � padding: const EdgeInsets.symmetric(vertical: 15),
� � � � � � � � � shape: RoundedRectangleBorder(
� � � � � � � � � � borderRadius: BorderRadius.circular(12),
� � � � � � � � � ),
� � � � � � � � � elevation: 5,
� � � � � � � � ),
� � � � � � � ),
� � � � � � ),

� � � � � � // --- ADD THIS NEW WIDGET HERE ---

� � � � � � const SizedBox(height: 10), // Add a small space between the two buttons

� � � � � � // Delete Account Button
� � � � � � SizedBox(
� � � � � � � width: double.infinity,
� � � � � � � child: OutlinedButton.icon(
� � � � � � � � onPressed: _handleAccountDeletion,
� � � � � � � � icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
� � � � � � � � label: Text('Delete Account', style: TextStyle(color: Colors.red.shade700, fontSize: 18)),
� � � � � � � � style: OutlinedButton.styleFrom(
� � � � � � � � � padding: const EdgeInsets.symmetric(vertical: 15),
� � � � � � � � � shape: RoundedRectangleBorder(
� � � � � � � � � � borderRadius: BorderRadius.circular(12),
� � � � � � � � � ),
� � � � � � � � � side: BorderSide(color: Colors.red.shade700, width: 2),
� � � � � � � � ),
� � � � � � � ),
� � � � � � ),

� � � � � � // --- Unique Ideas (Placeholders for now) ---
� � � � � � const SizedBox(height: 40),
� � � � � � Text(
� � � � � � � 'Unique Ideas (Coming Soon):',
� � � � � � � style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primary),
� � � � � � ),
� � � � � � const SizedBox(height: 10),
� � � � � � _buildComingSoonItem(color, '✅ Buyer–Seller Switch Toggle'),
� � � � � � _buildComingSoonItem(color, '📦 Live Order Map Tracker'),
� � � � � � _buildComingSoonItem(color, '🎉 Achievements/Badges'),
� � � � � � _buildComingSoonItem(color, '💬 Community Forum Link'),
� � � � � � _buildComingSoonItem(color, '📈 Quick Stats Card (for Vendors)'),
� � � � � � _buildComingSoonItem(color, '🔔 Smart Alerts'),
� � � � � � const SizedBox(height: 40),
� � � � � ],
� � � � ),
� � � ),
� � );
� }

� // --- Helper Widgets for Sections ---

� Widget _buildProfileSection(ColorScheme color) {
� � return Column(
� � � children: [
� � � � Center(
� � � � � child: CircleAvatar(
� � � � � � radius: 50,
� � � � � � backgroundColor: color.surface, // Fallback background for avatar
� � � � � � child: ClipOval(
� � � � � � � child: SizedBox.expand(
� � � � � � � � child: CachedNetworkImage(
� � � � � � � � � imageUrl: _profilePicUrl,
� � � � � � � � � fit: BoxFit.cover,
� � � � � � � � � placeholder: (context, url) => Center(
� � � � � � � � � � child: CircularProgressIndicator(color: color.primary),
� � � � � � � � � ),
� � � � � � � � � errorWidget: (context, url, error) {
� � � � � � � � � � return Icon(Icons.person, size: 60, color: color.onSurface.withOpacity(0.5));
� � � � � � � � � },
� � � � � � � � ),
� � � � � � � ),
� � � � � � ),
� � � � � ),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � Text(
� � � � � '${_firstName} ${_lastName}',
� � � � � style: TextStyle(
� � � � � � fontSize: 24,
� � � � � � fontWeight: FontWeight.bold,
� � � � � � color: color.onBackground, // Use onBackground for main text
� � � � � ),
� � � � ),
� � � � const SizedBox(height: 5),
� � � � Text(
� � � � � _email,
� � � � � style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
� � � � ),
� � � � Text(
� � � � � _phoneNumber,
� � � � � style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.7)),
� � � � ),
� � � � const SizedBox(height: 15),
� � � � SizedBox(
� � � � � width: double.infinity,
� � � � � child: OutlinedButton.icon(
� � � � � � onPressed: () async {
� � � � � � � final bool? result = await Navigator.of(context).push(
� � � � � � � � MaterialPageRoute(builder: (context) => const EditProfileScreen()),
� � � � � � � );
� � � � � � � if (result == true) {
� � � � � � � � _fetchUserData(); // Refresh AccountScreen data after profile is updated
� � � � � � � }
� � � � � � },
� � � � � � icon: Icon(Icons.edit, color: color.primary),
� � � � � � label: Text('Edit Profile', style: TextStyle(color: color.primary)),
� � � � � � style: OutlinedButton.styleFrom(
� � � � � � � side: BorderSide(color: color.primary), // Border matches primary color
� � � � � � � shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
� � � � � � ),
� � � � � ),
� � � � ),
� � � ],
� � );
� }

� Widget _buildBuyerSection(ColorScheme color) {
� � return Column(
� � � crossAxisAlignment: CrossAxisAlignment.start,
� � � children: [
� � � � Text(
� � � � � 'Buyer Tools',
� � � � � style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.shopping_bag_outlined,
� � � � � 'My Orders',
� � � � � 'Track all current & past orders',
� � � � � � � () {
� � � � � � Navigator.of(context).push(
� � � � � � � MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.favorite_outline,
� � � � � 'Saved Items (Wishlist)',
� � � � � 'Easily revisit products you liked',
� � � � � � � () {
� � � � � � Navigator.of(context).push(
� � � � � � � MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.account_balance_wallet_outlined,
� � � � � 'My Wallet / Payment Methods',
� � � � � 'Wallet balance: ₦${_userWalletBalance.toStringAsFixed(2)}',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(builder: (context) => const MyWalletScreen()),
� � � � � � );
� � � � � � _fetchUserData(); // Refresh account data after returning from wallet screen
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.location_on_outlined,
� � � � � 'Delivery Addresses',
� � � � � 'Manage your shipping locations',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(builder: (context) => const DeliveryAddressesScreen()),
� � � � � � );
� � � � � � _fetchUserData(); // Refresh account data after returning from addresses screen
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.star_outline,
� � � � � 'Reviews & Ratings',
� � � � � 'View products you reviewed',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(builder: (context) => const ReviewsRatingsScreen()),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.assignment_return_outlined,
� � � � � 'Returns & Disputes',
� � � � � 'View initiated return requests',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(
� � � � � � � � builder: (context) => const DisputeListScreen(),
� � � � � � � ),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.help_outline,
� � � � � 'Help Center',
� � � � � 'FAQs, live chat, contact support',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(
� � � � � � � � builder: (context) => const FAQScreen(),
� � � � � � � ),
� � � � � � );
� � � � � },
� � � � ),
� � � ],
� � );
� }
� Widget _buildVendorToolsSection(ColorScheme color) {
� � return Column(
� � � crossAxisAlignment: CrossAxisAlignment.start,
� � � children: [
� � � � Text(
� � � � � 'Vendor Tools',
� � � � � style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.inventory_2_outlined,
� � � � � 'My Products',
� � � � � 'View/manage inventory (${_totalProducts} total, ${_productsUnsold} unsold)',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(
� � � � � � � � builder: (context) => const VendorMyProductsScreen(),
� � � � � � � ),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.receipt_long_outlined,
� � � � � 'Orders Received',
� � � � � 'View buyer orders (${_productsSold} products sold)',
� � � � � � � () async {
� � � � � � await Navigator.of(context).push(
� � � � � � � MaterialPageRoute(
� � � � � � � � builder: (context) => const OrdersRecivedScreen(),
� � � � � � � ),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.payments_outlined,
� � � � � 'Earnings Dashboard',
� � � � � 'Vendor Wallet: ₦${_vendorWalletBalance.toStringAsFixed(2)} | App Wallet: ₦${_appWalletBalance.toStringAsFixed(2)}',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Earnings Dashboard functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.campaign_outlined,
� � � � � 'Promotions & Ads',
� � � � � 'Promote a product, view ad performance',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Promotions & Ads functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.store_outlined,
� � � � � 'Store Profile',
� � � � � 'Edit store logo, bio, name',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Store Profile functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.message_outlined,
� � � � � 'Messages from Buyers',
� � � � � 'Buyer inquiries or complaints',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Messages from Buyers functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � ],
� � );
� }

� // 🌟 NEW HELPER METHOD FOR PHARMACIST DASHBOARD
� Widget _buildPharmacistToolsSection(ColorScheme color) {
� � return Column(
� � � crossAxisAlignment: CrossAxisAlignment.start,
� � � children: [
� � � � Text(
� � � � � 'Pharmacist Tools',
� � � � � style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.local_pharmacy_outlined,
� � � � � 'Pharmacist Dashboard',
� � � � � 'Manage incoming prescription requests',
� � � � � () {
� � � � � � Navigator.of(context).push(
� � � � � � � MaterialPageRoute(
� � � � � � � � builder: (context) => const PharmacistDashboard(),
� � � � � � � ),
� � � � � � );
� � � � � },
� � � � ),
� � � ],
� � );
� }

� Widget _buildBecomeVendorCTA(ColorScheme color) {
� � return Column(
� � � crossAxisAlignment: CrossAxisAlignment.start,
� � � children: [
� � � � Text(
� � � � � 'Become a Vendor',
� � � � � style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � Card(
� � � � � elevation: 2,
� � � � � shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
� � � � � color: color.surface, // Card background color
� � � � � child: Padding(
� � � � � � padding: const EdgeInsets.all(16.0),
� � � � � � child: Column(
� � � � � � � crossAxisAlignment: CrossAxisAlignment.start,
� � � � � � � children: [
� � � � � � � � Text(
� � � � � � � � � 'Want to sell your products on NaijaGo?',
� � � � � � � � � style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color.onSurface),
� � � � � � � � ),
� � � � � � � � const SizedBox(height: 10),
� � � � � � � � Text(
� � � � � � � � � 'Register as a vendor to list your products and manage your sales.',
� � � � � � � � � style: TextStyle(fontSize: 14, color: color.onSurface.withOpacity(0.7)),
� � � � � � � � ),
� � � � � � � � const SizedBox(height: 15),
� � � � � � � � SizedBox(
� � � � � � � � � width: double.infinity,
� � � � � � � � � child: ElevatedButton.icon(
� � � � � � � � � � onPressed: () {
� � � � � � � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � � � � � � const SnackBar(content: Text('Vendor Registration coming soon!')),
� � � � � � � � � � � );
� � � � � � � � � � },
� � � � � � � � � � icon: Icon(Icons.store_mall_directory_outlined, color: color.onPrimary),
� � � � � � � � � � label: Text('Register as Vendor', style: TextStyle(color: color.onPrimary)),
� � � � � � � � � � style: ElevatedButton.styleFrom(
� � � � � � � � � � � backgroundColor: color.primary,
� � � � � � � � � � � shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
� � � � � � � � � � ),
� � � � � � � � � ),
� � � � � � � � ),
� � � � � � � ],
� � � � � � ),
� � � � � ),
� � � � ),
� � � ],
� � );
� }

� Widget _buildCommonToolsSection(ColorScheme color) {
� � return Column(
� � � crossAxisAlignment: CrossAxisAlignment.start,
� � � children: [
� � � � Text(
� � � � � 'Common Tools',
� � � � � style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.primary),
� � � � ),
� � � � const SizedBox(height: 10),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.notifications_none,
� � � � � 'Notification Settings',
� � � � � 'Manage your notification preferences',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Notification Settings functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � � // ✅ The Dark Mode Toggle now navigates to the SettingsScreen
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.brightness_4_outlined,
� � � � � 'Dark Mode Toggle',
� � � � � 'Switch between light and dark themes',
� � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('This Feature is Coming Soon')),
� � � � � � );
� � � � � }
� � � � � // � � () {
� � � � � // � // Navigate to the SettingsScreen class, which is defined in main.dart
� � � � � // � Navigator.of(context).push(
� � � � � // � � MaterialPageRoute(builder: (context) => const SettingsScreen()),
� � � � � // � );
� � � � � // },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.language_outlined,
� � � � � 'Language & Region',
� � � � � 'Change app language and region settings',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Language & Region functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � � _buildAccountListItem(
� � � � � context,
� � � � � color,
� � � � � Icons.share_outlined,
� � � � � 'Invite a Friend',
� � � � � 'Share NaijaGo with your friends',
� � � � � � � () {
� � � � � � ScaffoldMessenger.of(context).showSnackBar(
� � � � � � � const SnackBar(content: Text('Invite a Friend functionality coming soon!')),
� � � � � � );
� � � � � },
� � � � ),
� � � ],
� � );
� }

� // Helper for consistent list item styling
� Widget _buildAccountListItem(BuildContext context, ColorScheme color, IconData icon, String title, String subtitle, VoidCallback onTap) {
� � return Card(
� � � elevation: 2,
� � � shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
� � � margin: const EdgeInsets.symmetric(vertical: 6.0),
� � � color: color.surface, // Card background color
� � � child: ListTile(
� � � � leading: Icon(icon, color: color.primary, size: 28), // Icon color
� � � � title: Text(title, style: TextStyle(color: color.onSurface, fontWeight: FontWeight.w600)), // Title text color
� � � � subtitle: Text(subtitle, style: TextStyle(color: color.onSurface.withOpacity(0.7))), // Subtitle text color
� � � � trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color.onSurface.withOpacity(0.5)), // Arrow icon color
� � � � onTap: onTap,
� � � ),
� � );
� }

� Widget _buildComingSoonItem(ColorScheme color, String text) {
� � return Padding(
� � � padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
� � � child: Row(
� � � � children: [
� � � � � Icon(Icons.check_circle_outline, size: 20, color: greenYellow), // Checkmark icon color
� � � � � const SizedBox(width: 10),
� � � � � Expanded(
� � � � � � child: Text(
� � � � � � � text,
� � � � � � � style: TextStyle(fontSize: 16, color: color.onBackground.withOpacity(0.8)), // Text color
� � � � � � ),
� � � � � ),
� � � � ],
� � � ),
� � );
� }
}