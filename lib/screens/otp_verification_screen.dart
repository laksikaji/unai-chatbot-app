import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'supabase_service.dart';
import 'reset_password_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;

  const OTPVerificationScreen({super.key, required this.email});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  final _supabaseService = SupabaseService();

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getOTP() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 6 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบ OTP จากฐานข้อมูล
      final trimmedOtp = otp.trim();
      final trimmedEmail = widget.email.trim();

      debugPrint(
        'Checking OTP: "$trimmedOtp" (length: ${trimmedOtp.length}) for email: "$trimmedEmail"',
      );
      debugPrint('Email type: ${trimmedEmail.runtimeType}');
      debugPrint('OTP type: ${trimmedOtp.runtimeType}');

      // ลองดึงทุก OTP ของ email นี้ก่อน (case-insensitive)
      final allOtps = await _supabaseService.client
          .from('password_reset_otps')
          .select()
          .ilike('email', trimmedEmail);

      debugPrint('All OTPs for this email: $allOtps');

      // Debug: แสดง OTP แต่ละตัวในฐานข้อมูล
      if (allOtps.isNotEmpty) {
        debugPrint('Detailed OTP comparison:');
        for (var otpRecord in allOtps) {
          final dbOtp = otpRecord['otp_code']?.toString() ?? '';
          final dbEmail = otpRecord['email']?.toString() ?? '';
          final isUsed = otpRecord['is_used'] ?? true;
          debugPrint(
            '  DB Email: "$dbEmail" vs Input: "$trimmedEmail" = ${dbEmail == trimmedEmail}',
          );
          debugPrint(
            '  DB OTP: "$dbOtp" (length: ${dbOtp.length}, is_used: $isUsed)',
          );
          debugPrint(
            '  Input OTP: "$trimmedOtp" (length: ${trimmedOtp.length})',
          );
          debugPrint('  Match: ${dbOtp == trimmedOtp}');
        }
      }

      final response = await _supabaseService.client
          .from('password_reset_otps')
          .select()
          .ilike('email', trimmedEmail)
          .eq('otp_code', trimmedOtp)
          .eq('is_used', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('Query result: $response');

      // เช็ค expires_at manually
      if (response != null) {
        final expiresAt = DateTime.parse(
          response['expires_at'] as String,
        ).toUtc();
        final now = DateTime.now().toUtc();
        debugPrint('Expires at (UTC): $expiresAt');
        debugPrint('Current time (UTC): $now');
        debugPrint(
          'Time difference: ${now.difference(expiresAt).inMinutes} minutes',
        );

        if (now.isAfter(expiresAt)) {
          debugPrint('OTP expired!');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP expired, please request a new one'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (response == null) {
        // OTP is invalid or expired
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or expired OTP'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      debugPrint('OTP valid, marking as used...');
      debugPrint('Attempting to update OTP with ID: ${response['id']}');

      // ทำเครื่องหมายว่า OTP ถูกใช้แล้ว
      try {
        final updateResult = await _supabaseService.client
            .from('password_reset_otps')
            .update({'is_used': true})
            .eq('id', response['id'])
            .select()
            .single();

        debugPrint('Update successful!');
        debugPrint('Updated record: $updateResult');

        if (updateResult['is_used'] == true) {
          debugPrint('Confirmed: is_used is now TRUE');
        } else {
          debugPrint('Warning: is_used is still FALSE after update');
        }
      } catch (updateError) {
        debugPrint('Failed to update is_used!');
        debugPrint('Error type: ${updateError.runtimeType}');
        debugPrint('Error details: $updateError');
        // แม้ update ล้มเหลว ก็ยังให้ผ่านไปหน้า reset password
      }

      if (mounted) {
        // OTP ถูกต้อง ไปหน้า Reset Password
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(email: widget.email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'An error occurred, please try again';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a1e5e), Color(0xFF1a3a8a), Color(0xFF2563eb)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563eb), Color(0xFF1e40af)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/unai_logo.png',
                      width: 240,
                      height: 150,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'UNAi Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ENTER OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please enter the 6-digit OTP code\nsent to ${widget.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 50,
                          height: 60,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !_isLoading,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }

                              // Auto-verify when all 6 digits are entered
                              if (index == 5 && value.isNotEmpty) {
                                _verifyOTP();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3a8a),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'CONFIRM OTP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Back to Previous',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
