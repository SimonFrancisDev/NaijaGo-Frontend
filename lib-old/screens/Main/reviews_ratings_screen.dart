// lib/screens/Main/reviews_ratings_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/review.dart'; // Import the Review model
import 'product_detail_screen.dart'; // To navigate to product details if needed

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = Color(0xFF000080); // Deep Navy Blue - primary for backgrounds, cards
const Color greenYellow = Color(0xFFADFF2F); // Green Yellow - accent for important text, buttons
const Color whiteBackground = Colors.white; // Explicitly defining white for main backgrounds, text on navy
const Color starGold = Color(0xFFFFD700); // New Gold color for stars

class ReviewsRatingsScreen extends StatefulWidget {
  const ReviewsRatingsScreen({super.key});

  @override
  State<ReviewsRatingsScreen> createState() => _ReviewsRatingsScreenState();
}

class _ReviewsRatingsScreenState extends State<ReviewsRatingsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
  }

  Future<void> _fetchMyReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Assuming a backend endpoint to fetch reviews by the logged-in user
      // You might need to adjust this URL based on your actual backend implementation
      final Uri url = Uri.parse('$baseUrl/api/reviews/myreviews'); // Example endpoint
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> reviewsJson = jsonDecode(response.body);
        setState(() {
          _reviews = reviewsJson.map((json) => Review.fromJson(json)).toList();
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch reviews.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Check backend server and network.';
      });
      print('Error fetching reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed theme color scheme reference as we're using custom constants
    // final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: whiteBackground, // Main scaffold background is white
      appBar: AppBar(
        title: const Text(
          'My Reviews & Ratings',
          style: TextStyle(color: greenYellow), // AppBar title green yellow
        ),
        backgroundColor: deepNavyBlue, // AppBar background deep navy blue
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow), // AppBar icons green yellow
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: deepNavyBlue, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: deepNavyBlue, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchMyReviews,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepNavyBlue,
                            foregroundColor: greenYellow,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'You haven\'t submitted any reviews yet. Go find something you love!',
                          style: TextStyle(
                            color: deepNavyBlue.withOpacity(0.8), // Faded navy for empty state
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return Card(
                          elevation: 6, // More prominent elevation
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Rounded corners
                          color: deepNavyBlue, // Card background deep navy blue
                          child: Padding(
                            padding: const EdgeInsets.all(20.0), // Increased padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Name (if available)
                                if (review.productName != null)
                                  Text(
                                    review.productName!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: greenYellow, // Product name in green yellow
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                // Rating Stars
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < review.rating ? Icons.star : Icons.star_border,
                                      color: starGold, // Stars are now gold
                                      size: 22,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 12),
                                // Review Comment
                                Text(
                                  review.comment,
                                  style: const TextStyle(fontSize: 14, color: whiteBackground), // Comment text is now white
                                ),
                                const SizedBox(height: 12),
                                // Date of Review
                                Text(
                                  'Reviewed on: ${review.createdAt.toLocal().toIso8601String().split('T')[0]}',
                                  style: const TextStyle(fontSize: 12, color: whiteBackground), // Date text is now white
                                ),
                                // TODO: Add an option to edit/delete review if allowed by backend
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}