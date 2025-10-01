import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiDiagnosisScreen extends StatefulWidget {
  const AiDiagnosisScreen({super.key});

  @override
  State<AiDiagnosisScreen> createState() => _AiDiagnosisScreenState();
}

class _AiDiagnosisScreenState extends State<AiDiagnosisScreen> {
  final TextEditingController _controller = TextEditingController();
  String _diagnosis = '';
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF001F54); // Royal deep blue navy
  final Color secondaryColor = const Color(0xFF0D0D0D); // Deep black
  final Color accentColor = Colors.white;

  Future<void> _getDiagnosis() async {
    final inputText = _controller.text.trim();

    if (inputText.isEmpty) {
      setState(() {
        _diagnosis = "Please enter some symptoms before requesting a diagnosis.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _diagnosis = '';
    });

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _diagnosis = 'OpenAI API key not found. Check your .env file.';
      });
      return;
    }

    try {
      final prompt = "I have the following symptoms: $inputText. "
          "Give me a likely diagnosis or advice, but make it clear this isn't a substitute for seeing a doctor.";

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful medical assistant.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final message = body['choices']?[0]?['message']?['content'];

        setState(() {
          _diagnosis = message?.trim() ?? 'No diagnosis returned.';
        });
      } else {
        setState(() {
          _diagnosis = 'Failed to fetch diagnosis. (${response.statusCode})\n'
              'Reason: ${response.reasonPhrase}\n'
              'Details: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _diagnosis = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: accentColor,
      appBar: AppBar(
        title: const Text('AI Health Diagnosis'),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Describe your symptoms and our AI will give a likely diagnosis.",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF001F54),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "e.g. sore throat, high fever, dry cough...",
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getDiagnosis,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.medical_information),
              label: Text(
                _isLoading ? 'Diagnosing...' : 'Get Diagnosis',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _diagnosis.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _diagnosis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0D0D0D),
                          ),
                        ),
                      )
                    : const Text(
                        "Diagnosis will appear here.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
