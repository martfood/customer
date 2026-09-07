import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'email_service.dart';
import 'auth_error_handler.dart';
import '../../core/services/account_status_service.dart';

class LoginScreen extends StatefulWidget {
  final String? suspensionReason;
  final String? suspendedUntil;

  const LoginScreen({
    super.key,
    this.suspensionReason,
    this.suspendedUntil,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  String? _lastGoogleName;
  String? _lastGoogleEmail;
  String? _lastGooglePhoto;
  bool _hasPreviousGoogleLogin = false;

  @override
  void initState() {
    super.initState();
    _loadLastGoogleAccount();

    if (widget.suspensionReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AccountStatusService.showSuspensionSheet(
            context,
            reason: widget.suspensionReason!,
            suspendedUntil: widget.suspendedUntil,
          );
        }
      });
    }
  }

  Future<void> _loadLastGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastGoogleName = prefs.getString('last_google_name');
      _lastGoogleEmail = prefs.getString('last_google_email');
      _lastGooglePhoto = prefs.getString('last_google_photo');
      _hasPreviousGoogleLogin = prefs.getBool('has_previous_google_login') ?? false;
    });
  }

  Future<void> _saveGoogleAccount(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_google_name', user.displayName ?? 'Google User');
    await prefs.setString('last_google_email', user.email ?? '');
    await prefs.setString('last_google_photo', user.photoURL ?? '');
    await prefs.setBool('has_previous_google_login', true);
    _loadLastGoogleAccount();
  }

  Future<void> _handleGoogleSignIn({required bool switchAccount}) async {
    final router = GoRouter.of(context);
    setState(() {
      _isLoading = true;
    });
    try {
      final googleSignIn = GoogleSignIn();
      if (switchAccount) {
        await googleSignIn.signOut();
      }
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
        } else if (AccountStatusService.isSuspended(docSnap.data())) {
          final info = AccountStatusService.parseSuspension(docSnap.data());
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            AccountStatusService.showSuspensionSheet(
              context,
              reason: info.reason,
              suspendedUntil: info.suspendedUntil,
            );
          }
          return;
        }
      }

      if (mounted) {
        router.go('/home');
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AuthErrorHandler.showError(context, 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 5));

      final user = userCredential.user;
      if (user != null) {
        final docSnap = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();

        if (docSnap.exists && AccountStatusService.isSuspended(docSnap.data())) {
          final info = AccountStatusService.parseSuspension(docSnap.data());
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            AccountStatusService.showSuspensionSheet(
              context,
              reason: info.reason,
              suspendedUntil: info.suspendedUntil,
            );
          }
          return;
        }
      }

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _showForgotPasswordBottomSheet() {
    final emailController = TextEditingController(text: _emailController.text);
    bool dialogLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag Handle ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.authHeader),
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Enter your email address and we will send you a 6-digit OTP code to reset your password.',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 18.h),

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
                      controller: emailController,
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
                  SizedBox(height: 24.h),

                  // ── Action Button ────────────────────────────────────────
                  dialogLoading
                      ? Center(
                          child: CircularProgressIndicator(color: purpleColor),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) {
                                AuthErrorHandler.showError(context, 'Please enter your email address');
                                return;
                              }

                              setDialogState(() {
                                dialogLoading = true;
                              });

                              final otpCode = (100000 + Random().nextInt(900000)).toString();

                              try {
                                final normEmail = email.trim().toLowerCase();
                                final customerQuery = await FirebaseFirestore.instance
                                    .collection('customers')
                                    .where('email', isEqualTo: normEmail)
                                    .get()
                                    .timeout(const Duration(seconds: 5));

                                if (customerQuery.docs.isEmpty) {
                                  throw 'No customer account is registered with this email address.';
                                }

                                await FirebaseFirestore.instance
                                    .collection('password_resets')
                                    .doc(normEmail)
                                    .set({
                                  'otp': otpCode,
                                  'expiresAt': Timestamp.fromDate(
                                    DateTime.now().add(const Duration(minutes: 15)),
                                  ),
                                }).timeout(const Duration(seconds: 5));

                                final sent = await EmailService.sendPasswordResetOtp(email, otpCode);
                                if (context.mounted) {
                                  Navigator.pop(context); // Close bottom sheet
                                  if (sent) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Verification code sent to $email'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    AuthErrorHandler.showError(context, 'Failed to send email. Please try again.');
                                  }
                                  // Navigate to OTP entry screen
                                  context.push('/forgot-password-otp', extra: {
                                    'email': email,
                                    'otp': otpCode,
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AuthErrorHandler.showError(context, e);
                                }
                              } finally {
                                setDialogState(() {
                                  dialogLoading = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Text(
                              'Send Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTypography.font(AppFontSizes.titleMedium),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  SizedBox(height: 8.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.grey[400] : const Color(0xFF555555);

    Widget content = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),

            // ── 1. Header ───────────────────────────────────────────────────
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.authHeader),
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Login to continue ordering your favourites.',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                color: subtextColor,
              ),
            ),
            SizedBox(height: 28.h),

            // ── 2. Field 1: Email / Phone Number ─────────────────────────────
            Text(
              'Email / Phone Number',
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
                  hintText: 'Enter email or phone number',
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

            // ── 3. Field 2: Password ──────────────────────────────────────────
            Text(
              'Password',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.h),
            StatefulBuilder(
              builder: (context, setObscureState) {
                return _PasswordTextField(
                  controller: _passwordController,
                  fieldBg: fieldBg,
                  fieldBorder: fieldBorder,
                  textColor: textColor,
                  purpleColor: purpleColor,
                );
              },
            ),
            SizedBox(height: 8.h),

            // ── 4. Forgot Password (Left-aligned) ────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _showForgotPasswordBottomSheet,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password ?',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // ── 5. Login Button ──────────────────────────────────────────────
            _isLoading
                ? Center(child: CircularProgressIndicator(color: purpleColor))
                : SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: AppTypography.font(AppFontSizes.titleMedium),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

            SizedBox(height: 18.h),

            // ── 6. Don't have an account ? Sign Up ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account ? ",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/signup'),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      color: purpleColor,
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // ── 7. Or Divider ────────────────────────────────────────────────
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

            // ── 8. Previous Google Account Quick Login (If available) ─────────
            if (_hasPreviousGoogleLogin) ...[
              GestureDetector(
                onTap: () => _handleGoogleSignIn(switchAccount: false),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: purpleColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: purpleColor.withValues(alpha: 0.1),
                        backgroundImage: _lastGooglePhoto != null && _lastGooglePhoto!.isNotEmpty
                            ? NetworkImage(_lastGooglePhoto!)
                            : null,
                        child: _lastGooglePhoto == null || _lastGooglePhoto!.isEmpty
                            ? Icon(Icons.person, color: purpleColor)
                            : null,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Continue as ${_lastGoogleName ?? "Google User"}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                color: textColor,
                              ),
                            ),
                            Text(
                              _lastGoogleEmail ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14.sp, color: purpleColor),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // ── 9. Google Sign In Button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: OutlinedButton(
                onPressed: () => _handleGoogleSignIn(switchAccount: _hasPreviousGoogleLogin),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://pngimg.com/uploads/google/google_PNG19635.png',
                      height: 22.h,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.g_mobiledata,
                        size: 24.sp,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Sign in with Google',
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

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );

    if (isTablet) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: content,
    );
  }
}

/// Helper widget for password field with toggleable eye icon
class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final Color fieldBg;
  final Color fieldBorder;
  final Color textColor;
  final Color purpleColor;

  const _PasswordTextField({
    required this.controller,
    required this.fieldBg,
    required this.fieldBorder,
    required this.textColor,
    required this.purpleColor,
  });

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
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
          hintText: 'Enter password',
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
              size: 20.sp,
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
