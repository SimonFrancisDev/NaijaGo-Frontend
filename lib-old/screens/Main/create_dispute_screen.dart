import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/constants.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;
const Color whiteSmoke = Color(0xFFF5F5F5);

class CreateDisputeScreen extends StatefulWidget {
  final List<dynamic> orders;

  const CreateDisputeScreen({Key? key, required this.orders}) : super(key: key);

  @override
  State<CreateDisputeScreen> createState() => _CreateDisputeScreenState();
}

class _CreateDisputeScreenState extends State<CreateDisputeScreen> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedOrderId;
  List<PlatformFile> _attachments = [];
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _attachments = result.files;
      });
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> _uploadFile(PlatformFile file, String token) async {
    final uri = Uri.parse("$baseUrl/api/uploads/cloudinary");
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        file.bytes!,
        filename: file.name,
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        file.path!,
        filename: file.name,
      ));
    } else {
      print("File has no byte data or path: ${file.name}. Cannot upload.");
      return null;
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        return data['url'];
      } else {
        print("File upload failed with status code: ${response.statusCode}");
        final responseBody = await response.stream.bytesToString();
        print("Response body: $responseBody");
        return null;
      }
    } catch (e) {
      print("Error during file upload: $e");
      return null;
    }
  }

  Future<void> _submitDispute() async {
    if (_selectedOrderId == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select order and provide reason")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final token = await _getToken();
    
    if (token == null) {
      print("Authentication token not found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication token not found")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final List<String> attachmentUrls = [];
      for (final file in _attachments) {
        final url = await _uploadFile(file, token);
        if (url != null) {
          attachmentUrls.add(url);
        } else {
          print("Failed to upload file: ${file.name}. Aborting dispute creation.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload file: ${file.name}")),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final response = await http.post(
        Uri.parse("$baseUrl/api/disputes"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "orderId": _selectedOrderId,
          "reason": _reasonController.text,
          "attachments": attachmentUrls,
        }),
      );

      if (response.statusCode == 201) {
        print("Dispute created successfully!");
        Navigator.pop(context, true);
      } else {
        print("Dispute creation failed with status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (e) {
      print("Error during dispute creation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text("Create Dispute", style: TextStyle(color: greenYellow)),
        backgroundColor: deepNavyBlue,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedOrderId,
              style: const TextStyle(color: deepNavyBlue),
              items: widget.orders.map((order) {
                return DropdownMenuItem<String>(
                  value: order['_id'] as String,
                  child: Container(
                    color: whiteSmoke,
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Order ${order['_id']} - ₦${order['totalPrice']}",
                      style: const TextStyle(color: deepNavyBlue),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedOrderId = value),
              decoration: _inputDecoration(labelText: "Select Order"),
              isExpanded: true,
              dropdownColor: whiteBackground,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: deepNavyBlue),
              decoration: _inputDecoration(labelText: "Reason"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text("Attach Files"),
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: greenYellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
            const SizedBox(height: 8),
            if (_attachments.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments.map((f) => Chip(
                  label: Text(f.name, style: const TextStyle(color: deepNavyBlue)),
                  backgroundColor: greenYellow,
                  deleteIconColor: deepNavyBlue,
                  onDeleted: () => setState(() => _attachments.remove(f)),
                )).toList(),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitDispute,
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: greenYellow,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: greenYellow),
                    )
                  : const Text("Submit Dispute", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String labelText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: deepNavyBlue),
      filled: true,
      fillColor: deepNavyBlue.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: deepNavyBlue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: deepNavyBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: deepNavyBlue, width: 2),
      ),
    );
  }
}