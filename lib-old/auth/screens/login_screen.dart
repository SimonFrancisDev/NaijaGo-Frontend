


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../main.dart';
import './registration_screen.dart';
import './forgot_password_screen.dart';
import 'package:ionicons/ionicons.dart';
import 'package:local_auth/local_auth.dart'; // ⬅️ Added
import 'package:onesignal_flutter/onesignal_flutter.dart'; // ⬅️ Added OneSignal import

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  // 🔹 Fingerprint auth
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    bool canCheck = await auth.canCheckBiometrics;
    setState(() {
      _canCheckBiometrics = canCheck;
    });
  }

  Future<String> _getDeviceFingerprint() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.id ?? 'unknown_id'}-${androidInfo.model}';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.identifierForVendor ?? 'unknown_ios_vendor'}-${iosInfo.model}';
      }
    } catch (e) {
      print('Error getting device fingerprint: $e');
    }
    return 'unknown-device';
  }

  // 🔹 Get OneSignal Player ID - FIXED FOR SDK v5.x
Future<String?> _getOneSignalPlayerId() async {
  try {
    final String? pushId = OneSignal.User.pushSubscription.id;

    if (pushId != null && pushId.isNotEmpty) {
      print('OneSignal push subscription ID: $pushId');
      return pushId;
    } else {
      print('User not subscribed to push notifications or ID unavailable');
      return null;
    }
  } catch (e) {
    print('Error getting OneSignal push subscription ID: $e');
    return null;
  }
}


  // 🔹 Normal login (email/password)
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await _loginRequest(email, password);
  }

  // 🔹 Fingerprint login flow
  Future<void> _loginWithFingerprint() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        // 👇 Example: use stored email/password OR default values
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('user_email');
        final savedPassword = prefs.getString('user_password');

        if (savedEmail != null && savedPassword != null) {
          await _loginRequest(savedEmail, savedPassword);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No saved credentials found. Please login normally first.'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fingerprint error: $e")),
      );
    }
  }

  // 🔹 Shared login API call (UPDATED)
  Future<void> _loginRequest(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final deviceFingerprint = await _getDeviceFingerprint();
    final oneSignalPlayerId = await _getOneSignalPlayerId();

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/login');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
          'deviceFingerprint': deviceFingerprint,
          'oneSignalPlayerId': oneSignalPlayerId ?? '', // Send to backend
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String token = responseData['token'];
        final Map<String, dynamic> userData = responseData['user'];

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('device_fingerprint', deviceFingerprint);
        await prefs.setString('user', json.encode(userData));
        await prefs.setString('user_email', userData['email']);
        await prefs.setString('user_password', password);
        
        // Store OneSignal player ID for future use
        if (oneSignalPlayerId != null) {
          await prefs.setString('oneSignal_player_id', oneSignalPlayerId);
        }

        // Link OneSignal with user ID for better tracking
        try {
          await OneSignal.login(userData['id'].toString());
          await OneSignal.User.addTags({
            'user_id': userData['id'].toString(),
            'email': userData['email'],
            'last_login': DateTime.now().toIso8601String(),
          });
          print('OneSignal linked with user ID: ${userData['id']}');
        } catch (e) {
          print('Error linking OneSignal: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Login successful!')),
        );

        widget.onLoginSuccess();
      } else if (response.statusCode == 403 &&
          responseData['message'] ==
              'New device detected. Please check your email to verify this device.') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
      } else {
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      print('Login network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: color.primary,
      appBar: AppBar(
        title: Text('Login to NaijaGo', style: TextStyle(color: color.onPrimary)),
        backgroundColor: color.primary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back! 😊',
                  style: TextStyle(
                    color: color.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: color.onPrimary),
                  decoration: _inputDecoration('Email', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(color: color.onPrimary),
                  decoration: _inputDecoration('Password', color).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: color.onPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Please enter your password' : null,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: color.onPrimary.withOpacity(0.8),
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? CircularProgressIndicator(color: color.onPrimary)
                    : Column(
                        children: [
                          ElevatedButton(
                            onPressed: _loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color.onPrimary,
                              foregroundColor: color.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (_canCheckBiometrics)
                            ElevatedButton.icon(
                              onPressed: _loginWithFingerprint,
                              icon: const Icon(Icons.fingerprint, size: 28),
                              label: const Text("Login with Fingerprint or Face ID"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color.onPrimary,
                                foregroundColor: color.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                            ),
                        ],
                      ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    );
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      color: color.onPrimary,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
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
      labelStyle: TextStyle(color: color.onPrimary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: color.onPrimary, width: 2),
      ),
    );
  }
}