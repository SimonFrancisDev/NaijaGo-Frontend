// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:convert'; // For json.decode()
import 'package:http/http.dart' as http; // For http requests


import 'providers/cart_provider.dart';
import './screens/Main/main_app_navigator.dart';
import './auth/screens/login_screen.dart';
import './SplashScreen.dart';

const Color _lightPrimaryColor = Color.fromARGB(255, 3, 2, 76);
const Color _lightSecondaryColor = Color(0xFFADFF2F);
const Color _lightAccentColor = Color(0xFFF0F2F5);

const Color _darkPrimaryColor = Color.fromARGB(255, 144, 202, 249);
const Color _darkSecondaryColor = Color(0xFF64FFDA);
const Color _darkBackgroundColor = Color(0xFF121212);
const Color _darkSurfaceColor = Color(0xFF1E1E1E);

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: _lightPrimaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: const ColorScheme.light(
    primary: _lightPrimaryColor,
    onPrimary: Colors.white,
    secondary: _lightSecondaryColor,
    onSecondary: _lightPrimaryColor,
    background: Colors.white,
    onBackground: _lightPrimaryColor,
    surface: Colors.white,
    onSurface: _lightPrimaryColor,
    error: Colors.red,
    onError: Colors.white,
  ),
  cardColor: _lightAccentColor,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lightPrimaryColor,
      foregroundColor: Colors.white,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: _lightPrimaryColor),
    bodyMedium: TextStyle(color: _lightPrimaryColor),
    titleLarge: TextStyle(color: _lightPrimaryColor),
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  iconTheme: const IconThemeData(color: _lightPrimaryColor),
  splashColor: _lightSecondaryColor.withOpacity(0.5),
  highlightColor: _lightSecondaryColor.withOpacity(0.3),
  fontFamily: 'Roboto',
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _darkBackgroundColor,
  cardColor: _darkSurfaceColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: _darkSurfaceColor,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: const ColorScheme.dark(
    primary: _darkPrimaryColor,
    onPrimary: _darkBackgroundColor,
    secondary: _darkSecondaryColor,
    onSecondary: _darkBackgroundColor,
    background: _darkBackgroundColor,
    onBackground: Colors.white,
    surface: _darkSurfaceColor,
    onSurface: Colors.white,
    error: Colors.redAccent,
    onError: _darkBackgroundColor,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _darkPrimaryColor,
      foregroundColor: _darkBackgroundColor,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white),
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
  splashColor: _darkSecondaryColor.withOpacity(0.5),
  highlightColor: _darkSecondaryColor.withOpacity(0.3),
  fontFamily: 'Roboto',
);

class ThemeChanger extends StatefulWidget {
  final Widget child;

  const ThemeChanger({Key? key, required this.child}) : super(key: key);

  @override
  State<ThemeChanger> createState() => _ThemeChangerState();

  static _ThemeChangerState of(BuildContext context) {
    return context.findAncestorStateOfType<_ThemeChangerState>()!;
  }
}

class _ThemeChangerState extends State<ThemeChanger> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _saveThemeMode(themeMode);
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: widget.child,
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentThemePreference();
  }

  Future<void> _loadCurrentThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _onToggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });

    ThemeChanger.of(context).changeTheme(value ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _onToggleTheme,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class NaijaGoApp extends StatefulWidget {
  const NaijaGoApp({super.key});

  @override
  State<NaijaGoApp> createState() => _NaijaGoAppState();
}

class _NaijaGoAppState extends State<NaijaGoApp> {
  late Future<bool> _isLoggedInFuture; 
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeOneSignal();
    _isLoggedInFuture = _checkLoginStatus();
    
    // CRITICAL FIX: Request permission here, not in main()
    OneSignal.Notifications.requestPermission(true);
  }

  Future<void> _initializeOneSignal() async {
    _setupNotificationClickHandler();
    _setupUserTracking();
  }

  void _setupNotificationClickHandler() {
    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
      final additionalData = notification.additionalData;
      
      if (additionalData != null) {
        print('Notification clicked with data: $additionalData');
        
        if (additionalData['product_id'] != null) {
          print('Navigate to product: ${additionalData['product_id']}');
        }
        
        if (additionalData['type'] == 'abandoned_cart') {
          print('Navigate to cart');
        }
      }
    });
  }

  Future<void> _setupUserTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    if (token != null) {
      final userData = await _getUserDataFromBackend(token);
      if (userData != null) {
        // SDK v5.x FIX: Changed from setExternalUserId() to login()
        await OneSignal.login(userData['id']);
        
        await OneSignal.User.addTags({
          'user_id': userData['id'],
          'email': userData['email'],
          'total_purchases': userData['totalPurchases']?.toString() ?? '0',
          'last_purchase': userData['lastPurchaseDate'] ?? 'never',
          'customer_tier': userData['customerTier'] ?? 'new',
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserDataFromBackend(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://naijago-backend.onrender.com/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }


  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token != null;
  }

  void handleSplashFinished() {
    setState(() {
      _showSplash = false;
    });
  }

  void handleLoginSuccess() {
    setState(() {
      _isLoggedInFuture = Future.value(true);
    });
    _setupUserTracking();
  }

  void handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('order_count');
    
    // SDK v5.x FIX: Changed from removeExternalUserId() to logout()
    await OneSignal.logout();
    
    setState(() {
      _isLoggedInFuture = Future.value(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        Widget homeScreen;
        if (_showSplash) {
          homeScreen = SplashScreen(onSplashFinished: handleSplashFinished);
        } else {
          homeScreen = MainAppNavigator(onLogout: handleLogout);
        }

        return homeScreen;
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Initialize OneSignal early (before runApp)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  // SDK v5.x FIX: Removed 'await' from initialize() since it returns void
  OneSignal.initialize('76438b8d-4b39-49eb-805c-11eb934f5a66');
  // CRITICAL FIX: REMOVED permission request from here - moved to NaijaGoApp initState()

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const ThemeChanger(
        child: NaijaGoApp(),
      ),
    ),
  );
}