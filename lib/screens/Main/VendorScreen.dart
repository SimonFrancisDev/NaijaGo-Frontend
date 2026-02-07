// lib/screens/Main/VendorScreen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../constants.dart';
import '../vendor/add_product_screen.dart';
import '../../vendor/screens/vendor_registration_screen.dart';
import 'notifications_screen.dart';
import 'vendor_desist_confirmation_screen.dart';

// Defined custom colors for consistency
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;

class VendorScreen extends StatefulWidget {
  final bool isApprovedVendor;
  final String vendorStatus;
  final DateTime? rejectionDate;
  final double vendorWalletBalance;
  final double appWalletBalance;
  final double userWalletBalance;
  final int totalProducts;
  final int productsSold;
  final int productsUnsold;
  final int followersCount;
  final List<dynamic> notifications;
  final VoidCallback onRefresh;

  const VendorScreen({
    super.key,
    required this.isApprovedVendor,
    required this.vendorStatus,
    this.rejectionDate,
    required this.vendorWalletBalance,
    required this.appWalletBalance,
    required this.userWalletBalance,
    required this.totalProducts,
    required this.productsSold,
    required this.productsUnsold,
    required this.followersCount,
    required this.notifications,
    required this.onRefresh,
  });

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _countdownTimer;

  String _currentCountdownMessage = '';

  // New state variables for saved withdrawal info
  String? _savedBankName;
  String? _savedBankCode;
  String? _savedAccountNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('Flutter: VendorScreen initState called.');
    if (widget.vendorStatus == 'rejected' && widget.rejectionDate != null) {
      _startCountdownTimer();
    }
    _loadSavedWithdrawalDetails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  // New function to load saved details
  Future<void> _loadSavedWithdrawalDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedBankName = prefs.getString('savedBankName_vendor');
      _savedBankCode = prefs.getString('savedBankCode_vendor');
      _savedAccountNumber = prefs.getString('savedAccountNumber_vendor');
    });
  }

  @override
  void didUpdateWidget(covariant VendorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vendorStatus != oldWidget.vendorStatus || widget.rejectionDate != oldWidget.rejectionDate) {
      if (widget.vendorStatus == 'rejected' && widget.rejectionDate != null) {
        _startCountdownTimer();
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _currentCountdownMessage = '';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentCountdownMessage = _getCountdownMessage();
        if (_currentCountdownMessage == 'You can now submit a new vendor request!') {
          timer.cancel();
          widget.onRefresh();
        }
      });
    });
  }

  String _getCountdownMessage() {
    if (widget.rejectionDate == null) return '';

    final nextAttemptDate = widget.rejectionDate!.add(const Duration(days: 30));
    final now = DateTime.now();
    final difference = nextAttemptDate.difference(now);

    if (difference.isNegative) {
      return 'You can now submit a new vendor request!';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      return 'You can try again in $days days, $hours hours, $minutes minutes, $seconds seconds.';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (widget.vendorStatus) {
      case 'loading':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: deepNavyBlue),
            const SizedBox(height: 20),
            const Text(
              'Checking vendor status...',
              style: TextStyle(color: deepNavyBlue, fontSize: 16),
            ),
          ],
        );
        break;
      case 'none':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Become a Vendor!',
              style: TextStyle(color: deepNavyBlue, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const VendorRegistrationScreen()),
                );
                widget.onRefresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: greenYellow,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Register as Vendor', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
        break;
      case 'sent':
      case 'received':
      case 'reviewing':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: deepNavyBlue),
            const SizedBox(height: 20),
            const Text(
              'Vendor Request Status:',
              style: TextStyle(color: deepNavyBlue, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.vendorStatus.toUpperCase(),
              style: const TextStyle(color: deepNavyBlue, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Your request is currently being processed. We will notify you once it has been reviewed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: deepNavyBlue.withOpacity(0.8), fontSize: 16),
            ),
          ],
        );
        break;
      case 'approved':
        content = _buildVendorDashboard(context);
        break;
      case 'rejected':
        final canResubmit = widget.rejectionDate != null && DateTime.now().isAfter(widget.rejectionDate!.add(const Duration(days: 30)));
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, size: 80, color: deepNavyBlue),
            const SizedBox(height: 20),
            const Text(
              'Vendor Request Rejected',
              style: TextStyle(color: deepNavyBlue, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _currentCountdownMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: canResubmit ? greenYellow : deepNavyBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (canResubmit)
              ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const VendorRegistrationScreen()),
                  );
                  widget.onRefresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  foregroundColor: greenYellow,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Submit New Request', style: TextStyle(fontSize: 18)),
              ),
          ],
        );
        break;
      default:
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unknown vendor status. Please try again.',
              style: TextStyle(color: deepNavyBlue),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: greenYellow,
              ),
              child: const Text('Refresh Status'),
            ),
          ],
        );
        break;
    }

    return Scaffold(
      backgroundColor: whiteBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: content,
        ),
      ),
      floatingActionButton: widget.isApprovedVendor
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddProductScreen(),
                  ),
                );
                widget.onRefresh();
              },
              label: const Text('Add Product', style: TextStyle(color: greenYellow)),
              icon: const Icon(Icons.add, color: greenYellow),
              backgroundColor: deepNavyBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVendorDashboard(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome, Approved Vendor!',
            style: TextStyle(
              color: deepNavyBlue,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Wallets Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: whiteBackground,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Wallets',
                    style: TextStyle(color: deepNavyBlue, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20, thickness: 1, color: deepNavyBlue),
                  _buildWalletRow('Vendor Wallet:', widget.vendorWalletBalance),
                  _buildWalletRow('App Wallet:', widget.userWalletBalance),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showWithdrawDialog,
                        icon: const Icon(Icons.send, color: deepNavyBlue),
                        label: const Text('Withdraw', style: TextStyle(color: deepNavyBlue)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: whiteBackground,
                          side: const BorderSide(color: deepNavyBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Metrics Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: whiteBackground,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Metrics',
                    style: TextStyle(color: deepNavyBlue, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20, thickness: 1, color: deepNavyBlue),
                  _buildMetricRow('Followers:', widget.followersCount.toString()),
                  _buildMetricRow('Total Products:', widget.totalProducts.toString()),
                  _buildMetricRow('Products Sold:', widget.productsSold.toString()),
                  _buildMetricRow('Products Unsold:', widget.productsUnsold.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Desist from being a Vendor Button
          ElevatedButton(
            onPressed: () async {
              final bool? confirmed = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VendorDesistConfirmationScreen()),
              );
              if (confirmed == true) {
                _desistFromVendor();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: deepNavyBlue,
              foregroundColor: greenYellow,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Desist from being a Vendor', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: deepNavyBlue.withOpacity(0.9), fontSize: 16),
          ),
          Text(
            '₦${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: deepNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: deepNavyBlue.withOpacity(0.9), fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: deepNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<List<Map<String, String>>> _fetchBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        debugPrint('Authentication token not found. Cannot fetch banks.');
        return [];
      }

      final backendResp = await http.get(
        Uri.parse('$baseUrl/api/wallet/banks'),
        headers: _authHeaders(token),
      );

      if (backendResp.statusCode == 200) {
        final parsed = jsonDecode(backendResp.body);
        final List data = parsed['banks'] ?? [];
        return data.map<Map<String, String>>((b) => {
          'name': b['name'].toString(),
          'code': b['code'].toString(),
        }).toList();
      } else {
        debugPrint('Backend bank list error: ${backendResp.statusCode} ${backendResp.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      return [];
    }
  }

Future<Map<String, String>?> _showBankSelectionDialog(List<Map<String, String>> banks) {
  List<Map<String, String>> filteredBanks = List.from(banks); // <-- persists

  return showDialog<Map<String, String>?>(
    context: context,
    builder: (context) {
      final TextEditingController searchController = TextEditingController();

      return StatefulBuilder(
        builder: (context, setState) {
          void _filterBanks(String query) {
            setState(() {
              if (query.isEmpty) {
                filteredBanks = List.from(banks);
              } else {
                filteredBanks = banks
                    .where((bank) =>
                        bank['name']!.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              }
            });
          }

          return AlertDialog(
            title: const Text('Select a Bank', style: TextStyle(color: deepNavyBlue)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: _inputDecoration('Search for a bank...'),
                    onChanged: _filterBanks,
                  ),
                  const SizedBox(height: 12),
                  if (filteredBanks.isEmpty)
                    const Text(
                      'No banks found.',
                      style: TextStyle(
                        color: deepNavyBlue,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredBanks.length,
                        itemBuilder: (context, index) {
                          final bank = filteredBanks[index];
                          return ListTile(
                            title: Text(bank['name']!),
                            onTap: () {
                              Navigator.of(context).pop(bank);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
              ),
            ],
          );
        },
      );
    },
  );
}

  // UPDATED: This function now coordinates the entire two-step withdrawal process.
  void _showWithdrawDialog() async {
    _showSnack('Loading banks...');
    final banks = await _fetchBanks();

    if (!mounted) return;

    if (banks.isEmpty) {
      _showSnack('Failed to load bank list. Check your connection and try again.');
      return;
    }
    
    final TextEditingController accountNumberController = TextEditingController(text: _savedAccountNumber ?? '');
    final TextEditingController accountNameController = TextEditingController(text: '');
    final TextEditingController amountController = TextEditingController();
    
    String? selectedBankCode = _savedBankCode;
    String? selectedBankName = _savedBankName;
    bool saveDetails = false;

    // Show the initial dialog to collect withdrawal details.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: whiteBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Withdraw Funds', style: TextStyle(color: deepNavyBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_savedBankName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Last Used Details',
                          style: TextStyle(fontWeight: FontWeight.bold, color: deepNavyBlue),
                        ),
                      ),
                    
                    GestureDetector(
                      onTap: () async {
                        final result = await _showBankSelectionDialog(banks);
                        if (result != null) {
                          setState(() {
                            selectedBankName = result['name'];
                            selectedBankCode = result['code'];
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: deepNavyBlue),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedBankName ?? 'Select a bank...',
                                style: TextStyle(
                                  color: selectedBankName == null ? deepNavyBlue.withOpacity(0.6) : deepNavyBlue,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: deepNavyBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountNumberController,
                      decoration: _inputDecoration('Account Number'),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountNameController,
                      decoration: _inputDecoration('Account Holder Name'),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: _inputDecoration('Amount (₦)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: saveDetails,
                          onChanged: (bool? newValue) {
                            setState(() {
                              saveDetails = newValue ?? false;
                            });
                          },
                          activeColor: deepNavyBlue,
                        ),
                        const Text('Save these details?', style: TextStyle(color: deepNavyBlue)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate inputs and then call the new function to start the OTP flow.
                    final acct = accountNumberController.text.trim();
                    final accountName = accountNameController.text.trim();
                    final amtStr = amountController.text.trim();
                    final amount = double.tryParse(amtStr);

                    if (selectedBankCode == null || selectedBankCode!.isEmpty) {
                      _showSnack('Please select a bank.');
                      return;
                    }
                    if (acct.length != 10 || int.tryParse(acct) == null) {
                      _showSnack('Account number must be 10 digits.');
                      return;
                    }
                    if (accountName.isEmpty) {
                      _showSnack('Please enter account holder name.');
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      _showSnack('Enter a valid amount greater than 0.');
                      return;
                    }
                    if (amount > widget.vendorWalletBalance) {
                      _showSnack('Insufficient vendor wallet balance.');
                      return;
                    }
                    
                    Navigator.pop(context); // Dismiss the first dialog
                    _requestOtpAndWithdraw(
                      bankCode: selectedBankCode!,
                      accountNumber: acct,
                      accountName: accountName,
                      amount: amount,
                      saveDetails: saveDetails,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenYellow,
                    foregroundColor: deepNavyBlue,
                  ),
                  child: const Text('Request OTP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _sendOtpRequest(String token) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/request-otp'),
        headers: _authHeaders(token),
        body: jsonEncode({}),
      );
      
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _showSnack(body['message'] ?? 'OTP sent to your email.');
        return true;
      } else {
        final body = jsonDecode(resp.body);
        _showSnack(body['message'] ?? 'Failed to send OTP.');
        return false;
      }
    } catch (e) {
      debugPrint('OTP request error: $e');
      _showSnack('Network error during OTP request.');
      return false;
    }
  }

  Future<void> _requestOtpAndWithdraw({
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required double amount,
    required bool saveDetails,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _showSnack('Please log in again.');
        return;
      }
    
      _showSnack('Sending OTP to your registered email...');
    
      bool otpSent = await _sendOtpRequest(token);
    
      if (!otpSent) {
        _showSnack('Failed to send OTP. Please try again.');
        return;
      }
    
      final otp = await _showOtpDialog(
        onResend: () => _resendOtp(token),
      );

      if (otp != null && otp.isNotEmpty) {
        _submitWithdrawal(
          bankCode: bankCode,
          accountNumber: accountNumber,
          accountName: accountName,
          amount: amount,
          otp: otp,
          saveDetails: saveDetails,
        );
      } else {
        _showSnack('OTP submission canceled.');
      }
    } catch (e) {
      _showSnack('Network error during OTP request.');
      debugPrint('OTP request network error: $e');
    }
  }

  Future<String?> _showOtpDialog({required Future<bool> Function() onResend}) {
    final TextEditingController otpController = TextEditingController();
    
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        int _otpCountdown = 300;
        Timer? _timer;

        return StatefulBuilder(
          builder: (context, setState) {
            
            if (_timer == null || !_timer!.isActive) {
              _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!mounted) {
                  timer.cancel();
                  return;
                }
                setState(() {
                  if (_otpCountdown > 0) {
                    _otpCountdown--;
                  } else {
                    timer.cancel();
                  }
                });
              });
            }

            String minutes = (_otpCountdown ~/ 60).toString().padLeft(2, '0');
            String seconds = (_otpCountdown % 60).toString().padLeft(2, '0');
            String countdownText = '$minutes:$seconds';

            return AlertDialog(
              backgroundColor: whiteBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Enter OTP', style: TextStyle(color: deepNavyBlue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'An OTP has been sent to your email. Please enter it below.',
                    style: TextStyle(color: deepNavyBlue.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    decoration: _inputDecoration('Enter the 6-digit OTP'),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: _otpCountdown > 0,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Time remaining: $countdownText',
                    style: TextStyle(
                      color: _otpCountdown > 60 ? deepNavyBlue : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                if (_otpCountdown == 0)
                  ElevatedButton(
                    onPressed: () async {
                      _timer?.cancel();
                      bool success = await onResend();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('New OTP sent!'))
                        );
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenYellow,
                      foregroundColor: deepNavyBlue,
                    ),
                    child: const Text('Resend OTP'),
                  ),
                TextButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
                ),
                ElevatedButton(
                  onPressed: _otpCountdown > 0 && otpController.text.length == 6
                      ? () {
                          _timer?.cancel();
                          Navigator.pop(context, otpController.text.trim());
                        }
                      : null,
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _resendOtp(String token) async {
    _showSnack('Requesting new OTP...');
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/request-otp'),
        headers: _authHeaders(token),
        body: jsonEncode({}),
      );
    
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        _showSnack(body['message'] ?? 'New OTP sent to your email.');
        return true;
      } else {
        _showSnack(body['message'] ?? 'Failed to resend OTP. Please try again.');
        return false;
      }
    } catch (e) {
      _showSnack('Network error during OTP resend.');
      debugPrint('OTP resend network error: $e');
      return false;
    }
  }

  Future<void> _submitWithdrawal({
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required double amount,
    required String otp,
    required bool saveDetails,
  }) async {
    _showSnack('Processing withdrawal...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        _showSnack('Please log in again.');
        return;
      }

      if (saveDetails) {
        await prefs.setString('savedBankName_vendor', _savedBankName!);
        await prefs.setString('savedBankCode_vendor', bankCode);
        await prefs.setString('savedAccountNumber_vendor', accountNumber);
        _loadSavedWithdrawalDetails();
      }

      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/withdraw'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'bank_code': bankCode,
          'account_number': accountNumber,
          'account_name': accountName,
          'amount': amount,
          'otp': otp,
          'wallet_type': 'vendor',
        }),
      );

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        _showSnack(body['message'] ?? 'Withdrawal successful.');
        widget.onRefresh();
      } else {
        _showSnack(body['message'] ?? 'Withdrawal failed.');
        debugPrint('Withdraw error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _showSnack('Network error during withdrawal.');
      debugPrint('Withdraw network error: $e');
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: deepNavyBlue),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: deepNavyBlue),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: greenYellow, width: 2),
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Future<void> _desistFromVendor() async {
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
      final Uri url = Uri.parse('$baseUrl/api/auth/desist-vendor');
      final response = await http.put(
        url,
        headers: _authHeaders(token),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Successfully desisted from vendor status.')),
        );
        widget.onRefresh();
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to desist from vendor status.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while desisting: $e';
      });
      print('Desist vendor network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}