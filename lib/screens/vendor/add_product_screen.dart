import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants.dart';
import '../../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockQuantityController = TextEditingController();

  // Categories + Subcategories
  final Map<String, List<String>> _categorySections = {
    'Supermarket': ['Groceries', 'Baby Products', 'Others'],
    'Health & Beauty': ['Accessories', 'Perfume & Jewelry', 'Pharmacy'],
    'Fashion': ['Men', 'Women', 'Kids'],
    'Phones & Tablets': ['Smartphones', 'Tablets', 'Accessories'],
    'Electronics': ['TV & Audio', 'Computing', 'Gaming'],
    'Home & Office': ['Appliances', 'Sporting Goods', 'Books & Stationery', 'Automobiles & Tools'],
  };

  String? _selectedCategory; // e.g. "Fashion > Men"

  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFlashSale = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (image != null) {
        _selectedImage = File(image.path);
        _errorMessage = null;
      } else {
        _errorMessage = 'No image selected.';
      }
    });
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      if (_selectedCategory == null) {
        setState(() {
          _errorMessage = 'Please select a product category.';
        });
      }
      return;
    }

    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select a product image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    final double price = double.parse(_priceController.text);
    final int stockQuantity = int.parse(_stockQuantityController.text);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('$baseUrl/api/products');
    var request = http.MultipartRequest('POST', url);

    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();
    request.fields['category'] = _selectedCategory!; // <-- Updated
    request.fields['stockQuantity'] = stockQuantity.toString();
    request.fields['is_flashsale'] = _isFlashSale.toString();

    request.files.add(await http.MultipartFile.fromPath(
      'image',
      _selectedImage!.path,
      filename: _selectedImage!.path.split('/').last,
    ));

    request.headers['Authorization'] = 'Bearer $token';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Product added successfully!')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to add product.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      print('Add product network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🔽 Helper to build dropdown with headers + subcategories
  List<DropdownMenuItem<String>> _buildCategoryItems() {
    List<DropdownMenuItem<String>> items = [];

    _categorySections.forEach((section, subcategories) {
      // Section header (disabled)
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          child: Text(
            section,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
        ),
      );

      // Subcategories (indented)
      for (var sub in subcategories) {
        items.add(
          DropdownMenuItem<String>(
            value: "$section > $sub",
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(sub),
            ),
          ),
        );
      }
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Add New Product',
          style: TextStyle(color: color.onPrimary),
        ),
        backgroundColor: color.primary,
        elevation: 1,
        iconTheme: IconThemeData(color: color.onPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Product Details',
                  style: TextStyle(
                    color: color.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: color.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.primary, width: 2),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 50, color: color.primary),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to select Product Image',
                                style: TextStyle(color: color.onSurface, fontSize: 16),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Product Name
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Product Name', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Product Description', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Price
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Price', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product price';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Modern Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration('Category', color),
                  style: TextStyle(color: color.primary, fontSize: 16),
                  icon: Icon(Icons.arrow_drop_down, color: color.primary),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                  items: _buildCategoryItems(),
                ),
                const SizedBox(height: 15),

                // Stock Quantity
                TextFormField(
                  controller: _stockQuantityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Stock Quantity', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Flash Sale Checkbox
                CheckboxListTile(
                  title: Text(
                    'Mark as Flash Sale',
                    style: TextStyle(color: color.primary, fontSize: 16),
                  ),
                  tileColor: color.surfaceVariant,
                  value: _isFlashSale,
                  onChanged: (bool? newValue) {
                    setState(() {
                      _isFlashSale = newValue ?? false;
                    });
                  },
                  activeColor: color.secondary,
                  checkColor: color.onSecondary,
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    side: BorderSide(color: color.primary, width: 1.0),
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
                    ? Center(child: CircularProgressIndicator(color: color.primary))
                    : ElevatedButton(
                        onPressed: _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.primary,
                          foregroundColor: color.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: const Text(
                          'Add Product',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      labelStyle: TextStyle(color: color.primary.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: color.primary, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: color.secondary, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}