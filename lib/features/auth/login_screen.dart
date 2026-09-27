import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/network/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String _selectedRole = 'farmer';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      debugPrint('========================================');
      debugPrint('SMARTPROCURE LOGIN');
      debugPrint('Base URL: ${Env.apiBaseUrl}');
      debugPrint(
        'Endpoint: ${Env.apiBaseUrl}/api/v1/auth/login',
      );
      debugPrint('Username: $username');
      debugPrint('Role: $_selectedRole');
      debugPrint('========================================');

      final response = await ApiService.instance.client.post(
        '/api/v1/auth/login',
        data: {
          'username': username,
          'password': password,
          'role': _selectedRole,
          'centre_ids': <int>[],
        },
      );

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN RESPONSE: ${response.data}');

      if (response.data is! Map) {
        throw Exception(
          'Invalid response received from SmartProcure server.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(response.data as Map);

      final accessToken = data['access_token'];

      if (accessToken == null ||
          accessToken.toString().trim().isEmpty) {
        throw Exception(
          'Server did not return an access token.',
        );
      }

      final token = accessToken.toString().trim();

      // Save token and update Authorization header.
      await AuthService.setToken(token);

      if (!mounted) return;

      debugPrint('LOGIN SUCCESS');
      debugPrint('TOKEN SAVED');
      debugPrint('SELECTED ROLE: $_selectedRole');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful'),
          backgroundColor: Color(0xFF16803A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      // Navigate according to selected role.
      switch (_selectedRole.toLowerCase()) {
        case 'operator':
          context.go('/operator');
          break;

        case 'officer':
          context.go('/officer');
          break;

        case 'admin':
          context.go('/admin');
          break;

        case 'farmer':
        default:
          context.go('/farmer/home');
          break;
      }
    } on DioException catch (e) {
      if (!mounted) return;

      debugPrint('========================================');
      debugPrint('DIO LOGIN ERROR');
      debugPrint('Type: ${e.type}');
      debugPrint('Message: ${e.message}');
      debugPrint('URL: ${e.requestOptions.uri}');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('========================================');

      String message;

      if (e.response != null) {
        final status = e.response?.statusCode;
        final responseData = e.response?.data;

        if (status == 400) {
          message = 'Invalid login request.';
        } else if (status == 401) {
          message = 'Invalid username or password.';
        } else if (status == 403) {
          message = 'You are not authorized to login.';
        } else if (status == 404) {
          message =
          'Login API not found. Check the FastAPI route.';
        } else if (status == 422) {
          message =
          'Invalid login data. Please check the fields.';
        } else if (status != null && status >= 500) {
          message =
          'SmartProcure server error ($status).';
        } else {
          String detail = '';

          if (responseData is Map &&
              responseData['detail'] != null) {
            detail = responseData['detail'].toString();
          }

          message = detail.isNotEmpty
              ? detail
              : 'Login failed. Server returned $status.';
        }
      } else {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
            message =
            'Connection timeout. Check that FastAPI is running.';
            break;

          case DioExceptionType.receiveTimeout:
            message =
            'Server response timed out.';
            break;

          case DioExceptionType.sendTimeout:
            message =
            'Login request timed out.';
            break;

          case DioExceptionType.connectionError:
            message =
            'Cannot connect to SmartProcure server.';
            break;

          case DioExceptionType.badCertificate:
            message =
            'Server certificate problem.';
            break;

          default:
            message =
            'Network error: ${e.message ?? 'Unknown error'}';
        }
      }

      _showMessage(message, isError: true);
    } catch (e) {
      if (!mounted) return;

      debugPrint('========================================');
      debugPrint('LOGIN ERROR');
      debugPrint(e.toString());
      debugPrint('========================================');

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
        isError ? Colors.red.shade700 : const Color(0xFF16803A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16803A),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'SmartProcure',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF123B23),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Smart Farmer Procurement Platform',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style:
                            theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF17231B),
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Sign in to continue to SmartProcure',
                            style:
                            theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'Login as',
                            style:
                            theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor:
                              const Color(0xFFF9FBFA),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'farmer',
                                child: Text('Farmer'),
                              ),
                              DropdownMenuItem(
                                value: 'operator',
                                child: Text('Centre Operator'),
                              ),
                              DropdownMenuItem(
                                value: 'officer',
                                child: Text('District Officer'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Administrator'),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (value) {
                              if (value == null) return;

                              setState(() {
                                _selectedRole = value;
                              });
                            },
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Username / Mobile Number',
                            style:
                            theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextFormField(
                            controller: _usernameController,
                            enabled: !_isLoading,
                            autocorrect: false,
                            textInputAction:
                            TextInputAction.next,
                            decoration: InputDecoration(
                              hintText:
                              'Enter username or mobile number',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor:
                              const Color(0xFFF9FBFA),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Please enter username';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Password',
                            style:
                            theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextFormField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            textInputAction:
                            TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) {
                                _login();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                  setState(() {
                                    _obscurePassword =
                                    !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor:
                              const Color(0xFFF9FBFA),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Please enter password';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed:
                              _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF16803A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                Colors.grey.shade400,
                                elevation: 0,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.login_rounded,
                                    size: 21,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Secure Government Procurement Platform',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Ministry of Consumer Affairs, Food & Public Distribution',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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
