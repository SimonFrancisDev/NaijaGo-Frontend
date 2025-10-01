// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/cart_provider.dart';
import './screens/Main/main_app_navigator.dart';
import './auth/screens/login_screen.dart';
import './SplashScreen.dart';

// Defines the main colors for the application
const Color _lightPrimaryColor = Color.fromARGB(255, 3, 2, 76); // A deep navy blue
const Color _lightSecondaryColor = Color(0xFFADFF2F); // A bright green-yellow
const Color _lightAccentColor = Color(0xFFF0F2F5); // A light, neutral gray

const Color _darkPrimaryColor = Color.fromARGB(255, 144, 202, 249); // A light, readable blue
const Color _darkSecondaryColor = Color(0xFF64FFDA); // A cyan-like accent color
const Color _darkBackgroundColor = Color(0xFF121212); // The standard dark mode background
const Color _darkSurfaceColor = Color(0xFF1E1E1E); // A slightly lighter surface for cards

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
    // Use the primary color for most text, ensuring readability.
    bodyLarge: TextStyle(color: _lightPrimaryColor),
    bodyMedium: TextStyle(color: _lightPrimaryColor),
    titleLarge: TextStyle(color: _lightPrimaryColor),
    // Headline large can have its own color for emphasis.
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  iconTheme: const IconThemeData(color: _lightPrimaryColor),
  // Splash color should be an accent color for feedback.
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
    // Use white and white70 for text to ensure high contrast against the dark background.
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

// ... (The rest of your code remains the same)
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

// ... (The rest of your code like NaijaGoApp and main is unchanged)
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
    _isLoggedInFuture = _checkLoginStatus();
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
  }

  void handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('order_count');
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

        final bool isLoggedIn = snapshot.data ?? false;

        Widget homeScreen;
        if (_showSplash) {
          homeScreen = SplashScreen(onSplashFinished: handleSplashFinished);
        } else {
          homeScreen = isLoggedIn
              ? MainAppNavigator(onLogout: handleLogout)
              : LoginScreen(onLoginSuccess: handleLoginSuccess);
        }

        return homeScreen;
      },
    );
  }
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('jwt_token');

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

