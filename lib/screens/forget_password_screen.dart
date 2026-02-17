import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'otp_verification_screen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  final _supabaseService = SupabaseService();

  Future<void> _handleSendEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSending = true;
      });

      try {
        // เรียก Edge Function เพื่อส่ง OTP
        final response = await _supabaseService.client.functions.invoke(
          'send-password-reset-otp',
          body: {'email': _emailController.text.trim()},
        );

        if (mounted) {
          setState(() {
            _isSending = false;
          });

          if (response.status == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP sent to your email'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // รอ 500ms เพื่อให้ Edge Function บันทึก OTP ลงฐานข้อมูลเสร็จก่อน
            await Future.delayed(const Duration(milliseconds: 500));

            // ไปหน้า OTP Verification
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    email: _emailController.text.trim(),
                  ),
                ),
              );
            }
          } else {
            // แสดง error
            final errorData = response.data;
            final errorMessage = errorData is Map
                ? (errorData['error'] ?? 'Failed to send OTP')
                : 'Failed to send OTP';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSending = false;
          });

          String errorMessage = 'Failed to send OTP';

          if (e.toString().contains('Email not found')) {
            errorMessage = 'Email not found in system';
          } else if (e.toString().contains('Network')) {
            errorMessage = 'Cannot connect to internet';
          }

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
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/unai_logo.png', width: 240, height: 150),
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
            'FORGET PASSWORD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please enter your email\nWe will send you a password reset link',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isSending,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.email, color: Colors.black54),
              hintText: 'EMAIL',
              hintStyle: const TextStyle(
                color: Color(0xFF94a3b8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter email';
              }
              if (!value.contains('@')) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _handleSendEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a8a),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 4,
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SEND OTP',
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
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: const Text(
              'Back to Login',
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
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
