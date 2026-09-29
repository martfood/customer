import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_service.dart';
import 'auth_error_handler.dart';
import '../../core/services/account_status_service.dart';
import '../../core/utils/custom_snackbar.dart';

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

  @override
  void initState() {
    super.initState();

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

        if (docSnap.exists) {
          if (AccountStatusService.isSuspended(docSnap.data())) {
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
        } else {
          // Document does not exist in customers collection -> prompt customer profile activation
          if (mounted) {
            _showActivateCustomerProfileBottomSheet(user);
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

  void _showActivateCustomerProfileBottomSheet(User user) async {
    String existingName = '';
    String existingPhone = '';
    String existingPhotoUrl = '';

    try {
      final riderDoc = await FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .get();
      if (riderDoc.exists && riderDoc.data() != null) {
        final d = riderDoc.data()!;
        existingName = (d['fullName'] ?? '').toString();
        existingPhone = (d['phone'] ?? '').toString();
        existingPhotoUrl = (d['photoUrl'] ?? '').toString();
      } else {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(user.uid)
            .get();
        if (vendorDoc.exists && vendorDoc.data() != null) {
          final d = vendorDoc.data()!;
          existingName = (d['fullName'] ?? '').toString();
          existingPhone = (d['phone'] ?? '').toString();
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;

    bool isActivating = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      elevation: 0,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Responsive.maxContainer(
                context: ctx,
                maxWidth: 450,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: purpleColor,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Activate Customer Account',
                        style: TextStyle(
                          fontSize: AppTypography.font(20),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We found your MartFood account (${user.email}). Would you like to activate customer ordering with this account?',
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          color: mutedTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isActivating
                            ? null
                            : () async {
                                setSheetState(() => isActivating = true);
                                try {
                                  final fullName = existingName.isNotEmpty
                                      ? existingName
                                      : (user.displayName ?? user.email!.split('@').first);
                                  await FirebaseFirestore.instance
                                      .collection('customers')
                                      .doc(user.uid)
                                      .set({
                                    'uid': user.uid,
                                    'email': user.email ?? '',
                                    'fullName': fullName,
                                    'phoneNumber': existingPhone,
                                    'profilePic': existingPhotoUrl,
                                    'balance': 0.0,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    context.go('/home');
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setSheetState(() => isActivating = false);
                                  }
                                  if (mounted) {
                                    AuthErrorHandler.showError(context, e);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isActivating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Activate & Order Now',
                                style: TextStyle(
                                  fontSize: AppTypography.font(15),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isActivating
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await FirebaseAuth.instance.signOut();
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                          color: AppTheme.hintColorFor(isDark),
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
                                    CustomSnackBar.show(
                                      context,
                                      message: 'Verification code sent to $email',
                                      type: SnackBarType.success,
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
    final subtextColor = AppTheme.mutedTextColorFor(isDark);

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
                    color: AppTheme.hintColorFor(isDark),
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

            // ── 8. Continue as Guest Button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: purpleColor,
                  side: BorderSide(
                    color: purpleColor,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue as Guest',
                      style: TextStyle(
                        color: purpleColor,
                        fontSize: AppTypography.font(AppFontSizes.titleMedium),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(Icons.arrow_forward, size: 18.sp, color: purpleColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: AppTheme.hintColorFor(isDark),
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
