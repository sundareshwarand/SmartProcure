import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_service.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;

  const OtpScreen({
    super.key,
    required this.phone,
    this.role = 'farmer',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _api = ApiService.instance.client;

  bool _loading = false;
  String? _message;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() => _message = 'Enter the 6-digit OTP');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final response = await _api.post(
        '/otp/verify',
        data: {
          'phone': widget.phone,
          'otp': otp,
          'role': widget.role,
        },
      );

      final data = response.data;

      if (data['success'] == true) {
        setState(() {
          _message = 'OTP verified successfully';
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified successfully'),
          ),
        );

        Navigator.of(context).pop(data);
      } else {
        setState(() {
          _message = data['message'] ?? 'OTP verification failed';
        });
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];

      setState(() {
        _message = detail?.toString() ?? 'OTP verification failed';
      });
    } catch (e) {
      setState(() {
        _message = 'Unable to verify OTP';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Mobile Number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the OTP sent to ${widget.phone}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOtp,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'VERIFY OTP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
