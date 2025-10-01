import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import './auth/screens/login_screen.dart'; // Adjust the path if needed

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay for ~5 seconds (based on animation timing), then go to Login
    Future.delayed(const Duration(milliseconds: 5200), () {
      widget.onSplashFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: color.primary, // Royal Blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image with fade + slide + beat animation
            Image.asset(
              'assets/bg-erased_logo.png',
              width: 150,
              height: 150,
            )
                .animate()
                .fadeIn(duration: 1200.ms)
                .slideY(begin: 0.4, end: 0.0, duration: 1200.ms)
                .then()
                .scaleXY(
                  begin: 1.0,
                  end: 1.1,
                  curve: Curves.easeInOut,
                  duration: 400.ms,
                )
                .then(delay: 200.ms)
                .scaleXY(
                  begin: 1.1,
                  end: 1.0,
                  curve: Curves.easeInOut,
                  duration: 400.ms,
                )
                .then(delay: 200.ms)
                .scaleXY(
                  begin: 1.0,
                  end: 1.1,
                  curve: Curves.easeInOut,
                  duration: 400.ms,
                )
                .then(delay: 200.ms)
                .scaleXY(
                  begin: 1.1,
                  end: 1.0,
                  curve: Curves.easeInOut,
                  duration: 400.ms,
                ),

            const SizedBox(height: 4),

            // Enchanting Message
            Text(
              'Shop at a GO, Shop at your convenience.\nEmpowering Vendors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 1400.ms),
          ],
        ),
      ),
    );
  }
}
