import 'package:flutter/material.dart';

// Defined custom colors for consistency
const Color deepNavyBlue = Color(0xFF000080); // Deep Navy Blue
const Color greenYellow = Color(0xFFADFF2F); // Green Yellow
const Color whiteBackground = Colors.white; // Explicitly defining white for backgrounds
const Color whiteWarning = Color.fromARGB(255, 255, 2, 2); // Explicitly defining white for backgrounds

class VendorDesistConfirmationScreen extends StatelessWidget {
  const VendorDesistConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text(
          'Confirm Desist',
          style: TextStyle(color: greenYellow),
        ),
        backgroundColor: deepNavyBlue,
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: whiteWarning,
              ),
              const SizedBox(height: 30),
              const Text(
                'Are you sure you want to desist from being a vendor?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: deepNavyBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'This action will revoke your vendor privileges and you will no longer be able to add or manage products. You can re-apply later if needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: whiteWarning.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false); // User cancelled
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: whiteBackground,
                      foregroundColor: deepNavyBlue,
                      side: const BorderSide(color: deepNavyBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true); // User confirmed
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepNavyBlue,
                      foregroundColor: greenYellow,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirm Desist', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}