import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:country_picker/country_picker.dart';
import 'email_service.dart';
import 'auth_error_handler.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  
  Future<void> _saveGoogleAccount(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_google_name', user.displayName ?? 'Google User');
    await prefs.setString('last_google_email', user.email ?? '');
    await prefs.setString('last_google_photo', user.photoURL ?? '');
    await prefs.setBool('has_previous_google_login', true);
  }
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;
  String _selectedCountryCode = '+234';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();

    if (!_agreeToTerms) {
      AuthErrorHandler.showError(
        context,
        'Please accept the Terms of Use and Privacy Policy to continue.',
      );
      return;
    }

    if (email.isEmpty || password.isEmpty || fullName.isEmpty || phoneNumber.isEmpty) {
      AuthErrorHandler.showError(context, 'Please fill all fields');
      return;
    }

    if (password.length < 6) {
      AuthErrorHandler.showError(context, 'Password must be at least 6 characters');
      return;
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final sanitizedPhone = cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone;
    if (sanitizedPhone.length < 10 || sanitizedPhone.length > 11) {
      AuthErrorHandler.showError(context, 'Enter a valid 10-digit phone number');
      return;
    }

    final phoneRegex = RegExp(r'^[789]\d{9}$');
    if (_selectedCountryCode == '+234' && !phoneRegex.hasMatch(sanitizedPhone)) {
      AuthErrorHandler.showError(context, 'Please enter a valid Nigerian phone number (e.g. 8031234567).');
      return;
    }

    final fullPhoneNumber = '$_selectedCountryCode$sanitizedPhone';

    setState(() {
      _isLoading = true;
    });

    final otpCode = (Random().nextInt(9000) + 1000).toString();
    debugPrint('[Resend Sandbox OTP Bypass] Code for $email: $otpCode (Copy this code to proceed.)');

    // Attempt to send email in background (don't block the UI if it takes time/fails)
    EmailService.sendOtpEmail(email, otpCode);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      context.push('/otp', extra: {
        'email': email,
        'password': password,
        'otp': otpCode,
        'fullName': fullName,
        'phoneNumber': fullPhoneNumber,
        'profilePicPath': _imageFile?.path ?? '',
      });
    }
  }

  bool _agreeToTerms = false;
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.grey[400] : const Color(0xFF555555);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),

              // ── 1. Header ───────────────────────────────────────────────────
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.authHeader),
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Join MartFood and start ordering today.',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: subtextColor,
                ),
              ),
              SizedBox(height: 20.h),

              // ── Optional Profile Picture Picker ─────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 36.r,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                        child: _imageFile == null
                            ? Icon(Icons.camera_alt_outlined, size: 28.sp, color: Colors.grey[600])
                            : null,
                      ),
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: purpleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, size: 12.sp, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // ── 2. Field 1: Full Name ────────────────────────────────────────
              Text(
                'Full Name',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // ── 3. Field 2: Phone Number ──────────────────────────────────────
              Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (Country country) {
                            setState(() {
                              _selectedCountryCode = '+${country.phoneCode}';
                            });
                          },
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            _selectedCountryCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                    Container(
                      height: 20.h,
                      width: 1,
                      color: Colors.grey[300],
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: textColor,
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),

              // ── 4. Field 3: Email Address ─────────────────────────────────────
              Text(
                'Email Address',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter email address',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // ── 5. Field 4: Password ──────────────────────────────────────────
              Text(
                'Password',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              _SignupPasswordTextField(
                controller: _passwordController,
                hintText: 'Create password',
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
                textColor: textColor,
                purpleColor: purpleColor,
              ),
              SizedBox(height: 18.h),

              // ── 6. Field 5: Confirm Password ──────────────────────────────────
              Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              _SignupPasswordTextField(
                controller: _confirmPasswordController,
                hintText: 'Confirm Password',
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
                textColor: textColor,
                purpleColor: purpleColor,
              ),
              SizedBox(height: 16.h),

              // ── 7. Terms & Conditions Row ───────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24.w,
                    width: 24.w,
                    child: Checkbox(
                      value: _agreeToTerms,
                      activeColor: purpleColor,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? true;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to MartFood ',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.bodySmall),
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms of Use',
                            style: TextStyle(
                              color: purpleColor,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: purpleColor,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                context.push('/profile/legal/terms-of-use');
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: purpleColor,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: purpleColor,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                context.push('/profile/legal/privacy-policy');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // ── 8. Sign Up Action Button ──────────────────────────────────────
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: purpleColor))
                  : SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _agreeToTerms ? _signUp : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          disabledBackgroundColor: purpleColor.withValues(alpha: 0.4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

              SizedBox(height: 18.h),

              // ── 9. Already have an account? Login ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: purpleColor,
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (defaultTargetPlatform != TargetPlatform.iOS) ...[
                SizedBox(height: 20.h),

                // ── 10. Or Divider ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'Or',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),

                SizedBox(height: 20.h),

                // ── 11. Social Sign Up Button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        final googleSignIn = GoogleSignIn();
                        final googleUser = await googleSignIn.signIn();
                        if (googleUser == null) {
                          setState(() {
                            _isLoading = false;
                          });
                          return;
                        }

                        final googleAuth = await googleUser.authentication;
                        final credential = GoogleAuthProvider.credential(
                          accessToken: googleAuth.accessToken,
                          idToken: googleAuth.idToken,
                        );

                        final userCredential = await FirebaseAuth.instance
                            .signInWithCredential(credential)
                            .timeout(const Duration(seconds: 10));

                        final user = userCredential.user;
                        if (user != null) {
                          await _saveGoogleAccount(user);
                          final docRef = FirebaseFirestore.instance
                              .collection('customers')
                              .doc(user.uid);
                          final docSnap = await docRef.get();

                          if (!docSnap.exists) {
                            await docRef.set({
                              'uid': user.uid,
                              'email': user.email ?? '',
                              'fullName': user.displayName ?? 'Google User',
                              'phoneNumber': user.phoneNumber ?? '',
                              'profilePic': user.photoURL ?? '',
                              'balance': 0.0,
                              'createdAt': FieldValue.serverTimestamp(),
                            }).timeout(const Duration(seconds: 5));
                          }
                        }

                        if (context.mounted) {
                          context.go('/home');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AuthErrorHandler.showError(context, e);
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://pngimg.com/uploads/google/google_PNG19635.png',
                          height: 22,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.g_mobiledata,
                            size: 24,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign up with Google',
                          style: TextStyle(
                            color: textColor,
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper widget for password field with toggleable eye icon
class _SignupPasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fieldBg;
  final Color fieldBorder;
  final Color textColor;
  final Color purpleColor;

  const _SignupPasswordTextField({
    required this.controller,
    required this.hintText,
    required this.fieldBg,
    required this.fieldBorder,
    required this.textColor,
    required this.purpleColor,
  });

  @override
  State<_SignupPasswordTextField> createState() => _SignupPasswordTextFieldState();
}

class _SignupPasswordTextFieldState extends State<_SignupPasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.fieldBg,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: widget.fieldBorder, width: 1.0),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        style: TextStyle(
          color: widget.textColor,
          fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: widget.purpleColor,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          ),
        ),
      ),
    );
  }
}

