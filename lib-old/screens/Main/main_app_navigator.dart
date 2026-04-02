// lib/screens/Main/main_app_navigator.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:provider/provider.dart'; // For accessing CartProvider
import 'package:naija_go/providers/cart_provider.dart'; // Ensure correct path
import 'package:naija_go/screens/Main/notifications_screen.dart'; // Import NotificationsScreen
import 'package:naija_go/screens/Main/vendor_desist_confirmation_screen.dart'; // Import VendorDesistConfirmationScreen
import 'package:naija_go/screens/vendor/add_product_screen.dart'; // Import AddProductScreen
import 'package:naija_go/vendor/screens/vendor_registration_screen.dart'; // Import VendorRegistrationScreen

// ADDED IMPORT: Needed to redirect unauthenticated users to login
import 'package:naija_go/auth/screens/login_screen.dart';


import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart'; // Import your base URL
import 'dart:async'; // For Timer

// Import your tab screens
import 'HomeScreen.dart';
import 'CartScreen.dart';
import 'categories_screen.dart';
import 'VendorScreen.dart';
import 'account_screen.dart';

// Import Ionicons for tab bar icons
import 'package:ionicons/ionicons.dart';

// New Widget to show when restricted content is accessed by guests
class GuestPlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onLoginTapped;

  const GuestPlaceholderScreen({
    Key? key,
    required this.title,
    required this.message,
    required this.onLoginTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.lock_closed_outline, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: onLoginTapped,
              icon: const Icon(Ionicons.log_in),
              label: const Text('Log In / Register'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainAppNavigator extends StatefulWidget {
  final VoidCallback onLogout;

  const MainAppNavigator({required this.onLogout, super.key});

  @override
  State<MainAppNavigator> createState() => _MainAppNavigatorState();
}

class _MainAppNavigatorState extends State<MainAppNavigator> with WidgetsBindingObserver {
  int _selectedIndex = 0; // Current selected tab index
  bool _isLoading = false;
  // NEW STATE: Tracks if the user is authenticated (token exists and is valid)
  bool _isLoggedIn = false;
  String? _errorMessage; // Retained for actual API errors (e.g., 401, network failure)

  // Data to be passed to VendorScreen
  bool _isApprovedVendor = false;
  String _vendorStatus = 'loading';
  DateTime? _rejectionDate;
  double _vendorWalletBalance = 0.0;
  double _appWalletBalance = 0.0;
  double _userWalletBalance = 0.0;
  int _totalProducts = 0;
  int _productsSold = 0;
  int _productsUnsold = 0;
  int _followersCount = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserStatus(); // Initial data fetch
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('Flutter: App resumed, re-fetching user status in MainAppNavigator.');
      _fetchUserStatus(); // Re-fetch data when app resumes
    }
  }
  
  // New function to navigate to the LoginScreen
  void _navigateToLogin() async {
    // Navigate to the LoginScreen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          // We pass a dummy onLoginSuccess callback here, but the actual 
          // state change is handled by NaijaGoApp in main.dart if we navigate
          // back from the login screen with a result.
          onLoginSuccess: () {
            // After successful login, close the LoginScreen
            Navigator.of(context).pop();
            // Re-fetch status to update UI and set _isLoggedIn to true
            _fetchUserStatus();
            // Go to Account tab
            _onItemTapped(4); 
          },
        ),
      ),
    );
    // If we return from the LoginScreen (via successful login or back button),
    // we should re-check the status in case they logged in.
    _fetchUserStatus();
  }


  // Helper to build the list of widgets dynamically based on current state
  List<Widget> get _widgetOptions {
    // These are the screens that can be accessed by guests
    Widget homeScreen = const HomeScreen();
    Widget categoriesScreen = const CategoriesScreen();

    // The Cart, Vendor, and Account tabs require authentication
    Widget protectedCartScreen = GuestPlaceholderScreen(
      title: 'Shopping Cart',
      message: 'Log in to view and manage your cart, wishlist, and orders.',
      onLoginTapped: _navigateToLogin,
    );
    
    Widget protectedVendorScreen = GuestPlaceholderScreen(
      title: 'Vendor Access',
      message: 'You must be logged in to apply to become a vendor or manage your store.',
      onLoginTapped: _navigateToLogin,
    );

    Widget protectedAccountScreen = GuestPlaceholderScreen(
      title: 'My Account',
      message: 'Log in to view your profile, orders, and settings.',
      onLoginTapped: _navigateToLogin,
    );


    return <Widget>[
      // Index 0: Home (Always Public)
      homeScreen,
      // Index 1: Cart (Protected)
      _isLoggedIn ? CartScreen(onOrderSuccess: _fetchUserStatus) : protectedCartScreen,
      // Index 2: Categories (Always Public)
      categoriesScreen,
      // Index 3: Vendor (Protected)
      _isLoggedIn
          ? VendorScreen(
              isApprovedVendor: _isApprovedVendor,
              vendorStatus: _vendorStatus,
              rejectionDate: _rejectionDate,
              vendorWalletBalance: _vendorWalletBalance,
              appWalletBalance: _appWalletBalance,
              userWalletBalance: _userWalletBalance,
              totalProducts: _totalProducts,
              productsSold: _productsSold,
              productsUnsold: _productsUnsold,
              followersCount: _followersCount,
              notifications: _notifications,
              onRefresh: _fetchUserStatus,
            )
          : protectedVendorScreen,
      // Index 4: Account (Protected)
      _isLoggedIn ? AccountScreen(onLogout: widget.onLogout) : protectedAccountScreen,
    ];
  }

  // Function to fetch the current user's profile and vendor status
  Future<void> _fetchUserStatus() async {
    if (_isLoading) {
      print('Flutter: _fetchUserStatus() already loading in MainAppNavigator, returning.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      print('Flutter: MainAppNavigator _isLoading set to true.');
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    // --- START: MODIFIED LOGIC FOR GUEST MODE ---
    if (token == null) {
      print('Flutter: No token found. Running in unauthenticated (guest) mode.');
      setState(() {
        _isLoggedIn = false; // Set authenticated state to false
        _isLoading = false;
        _errorMessage = null; // CRITICAL: Clear error message to display HomeScreen
        // Reset all protected/vendor data to safe defaults
        _isApprovedVendor = false;
        _vendorStatus = 'guest'; 
        _vendorWalletBalance = 0.0;
        _appWalletBalance = 0.0;
        _userWalletBalance = 0.0;
        _totalProducts = 0;
        _productsSold = 0;
        _productsUnsold = 0;
        _followersCount = 0;
        _notifications = [];
      });
      return; // Stop here, do not proceed with API calls
    }
    // --- END: MODIFIED LOGIC ---


    try {
      // API Call 1: Fetch general user data (including vendor status)
      final Uri userUrl = Uri.parse('$baseUrl/api/auth/me');
      print('Flutter: MainAppNavigator attempting to fetch user status from URL: $userUrl');
      final userResponse = await http.get(
        userUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      print('Flutter: MainAppNavigator received user response with status code: ${userResponse.statusCode}');

      if (userResponse.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(userResponse.body);
        
        final bool isApproved = userData['isVendor'] == true && userData['vendorStatus'] == 'approved';
        final String status = userData['vendorStatus'] ?? 'none';
        final double vendorBalance = (userData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final double appBalance = (userData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final double userBalance = (userData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;
        final DateTime? rejectionDate = (status == 'rejected' && userData['vendorRejectionDate'] != null)
            ? DateTime.parse(userData['vendorRejectionDate'])
            : null;
        final List<dynamic> notifications = userData['notifications'] ?? [];
        final int followers = userData['followersCount'] ?? 0;
        
        int totalProds = 0;
        int productsSold = 0;
        int productsUnsold = 0;

        // API Call 2: If the user is an approved vendor, fetch real-time stats
        if (isApproved) {
          print('User is an approved vendor. Fetching vendor stats.');
          final Uri statsUrl = Uri.parse('$baseUrl/api/vendor/stats');
          print('Flutter: Fetching vendor stats from URL: $statsUrl');
          final statsResponse = await http.get(
            statsUrl,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
          );

          if (statsResponse.statusCode == 200) {
            final Map<String, dynamic> statsData = jsonDecode(statsResponse.body);
            totalProds = statsData['totalProducts'] ?? 0;
            productsSold = statsData['productsSold'] ?? 0;
            productsUnsold = statsData['productsUnsold'] ?? 0;
            print('Flutter: Vendor stats fetched successfully. Products Sold: $productsSold');
          } else {
            print('Flutter: Failed to fetch vendor stats. Status Code: ${statsResponse.statusCode}');
          }
        }
        
        // Use a single setState to update all variables at once
        setState(() {
          _isLoggedIn = true; // Successfully authenticated
          _isApprovedVendor = isApproved;
          _vendorStatus = status;
          _vendorWalletBalance = vendorBalance;
          _appWalletBalance = appBalance;
          _userWalletBalance = userBalance;
          _rejectionDate = rejectionDate;
          _notifications = notifications;
          _followersCount = followers;
          _totalProducts = totalProds;
          _productsSold = productsSold;
          _productsUnsold = productsUnsold;
          print('Flutter: All vendor state variables updated.');
        });

      } else {
        // If token exists but is invalid (e.g., 401), treat as logged out but set an error
        final responseData = jsonDecode(userResponse.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch user status.';
          _isLoggedIn = false;
          _isApprovedVendor = false;
          _vendorStatus = 'none';
        });
        print('Flutter: MainAppNavigator failed to fetch user status. Status Code: ${userResponse.statusCode}, Message: ${responseData['message']}');
        if (userResponse.statusCode == 401) {
          prefs.remove('jwt_token');
          print('Flutter: Token invalid/expired, cleared from SharedPreferences.');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while fetching user status: $e';
        _isLoggedIn = false;
        _isApprovedVendor = false;
        _vendorStatus = 'none';
      });
      print('Flutter: MainAppNavigator fetch user status network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        print('Flutter: MainAppNavigator _isLoading set to false in finally block.');
      });
    }
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'NaijaGo Home';
      case 1:
        return 'Your Cart';
      case 2:
        return 'Product Categories';
      case 3:
        // Only show vendor dashboard title if logged in and approved
        if (!_isLoggedIn) return 'Vendor Section';
        return _isApprovedVendor ? 'Vendor Dashboard' : 'Vendor Section';
      case 4:
        return 'My Account';
      default:
        return 'NaijaGo';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define your deepNavyBlue color
    const Color deepNavyBlue = Color(0xFF03024C);
    
    final color = Theme.of(context).colorScheme;
    final cartProvider = Provider.of<CartProvider>(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: color.surface,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: color.secondary,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(_selectedIndex),
          style: const TextStyle(color: deepNavyBlue), // Changed title color
        ),
        backgroundColor: color.surface,
        elevation: 1,
        iconTheme: const IconThemeData(color: deepNavyBlue), // Added to color the back button
        actionsIconTheme: const IconThemeData(color: deepNavyBlue), // Added to color actions icons
        actions: [
          // Cart Icon and Badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Ionicons.cart_outline, color: deepNavyBlue), // Changed cart icon color
                onPressed: () {
                  _onItemTapped(1); // Navigate to Cart tab
                },
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cartProvider.itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Vendor Notifications Icon
          if (_isApprovedVendor && _selectedIndex == 3)
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: deepNavyBlue), // Changed notification icon color
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => NotificationsScreen(notifications: _notifications)),
                    );
                    _fetchUserStatus();
                  },
                ),
                if (_notifications.any((n) => !n['read']))
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        _notifications.where((n) => !n['read']).length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator(color: color.primary)
            // Show the error message only if a real API/Token error occurred, 
            // otherwise show the selected screen (which handles the 'guest' state)
            : _errorMessage != null
                ? Text(_errorMessage!, style: const TextStyle(color: Colors.red))
                : _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Ionicons.home_outline),
            activeIcon: Icon(Ionicons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.cart_outline),
            activeIcon: Icon(Ionicons.cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.grid_outline),
            activeIcon: Icon(Ionicons.grid),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.storefront_outline),
            activeIcon: Icon(Ionicons.storefront),
            label: 'Vendor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.person_outline),
            activeIcon: Icon(Ionicons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.lightGreenAccent,
        unselectedItemColor: Colors.white,
        onTap: _onItemTapped,
        backgroundColor: color.primary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      floatingActionButton: _selectedIndex == 3 && _isApprovedVendor
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                );
                _fetchUserStatus();
              },
              label: Text('Add Product', style: TextStyle(color: color.onPrimary)),
              icon: Icon(Icons.add, color: color.onPrimary),
              backgroundColor: color.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}