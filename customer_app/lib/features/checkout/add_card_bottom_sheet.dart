import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../wallet/paystack_service.dart';

/// Shows a beautiful 3-step card input & verification bottom sheet.
///
/// [email] – customer email for Paystack charge.
/// [amountInNaira] – amount to charge (50.0 for tokenization card setup or full order total).
Future<Map<String, dynamic>?> showAddCardBottomSheet({
  required BuildContext context,
  required String email,
  required double amountInNaira,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (ctx) => _AddCardSheet(
      email: email,
      amountInNaira: amountInNaira,
    ),
  );
}

class _AddCardSheet extends StatefulWidget {
  final String email;
  final double amountInNaira;

  const _AddCardSheet({
    required this.email,
    required this.amountInNaira,
  });

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Step 1: Card Details
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();

  final _cardNumberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _cardNameFocus = FocusNode();

  // Controller for Step 2: PIN
  final _pinCtrl = TextEditingController();

  // Controller for Step 3: OTP
  final _otpCtrl = TextEditingController();

  // Flow & State
  int _currentStep = 1; // 1 = Card Info, 2 = Enter PIN, 3 = Enter OTP
  bool _isProcessing = false;
  bool _obscureCvv = true;
  bool _obscurePin = true;
  String? _errorMessage;
  String _cardBrand = '';

  // Paystack pending transaction details
  String _pendingReference = '';
  String _otpDisplayText = '';

  @override
  void initState() {
    super.initState();
    _cardNumberCtrl.addListener(_onCardNumberChanged);
  }

  @override
  void dispose() {
    _cardNumberCtrl.removeListener(_onCardNumberChanged);
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cardNameCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _cardNameFocus.dispose();
    super.dispose();
  }

  void _onCardNumberChanged() {
    final digits = _cardNumberCtrl.text.replaceAll(' ', '');
    String brand = '';
    if (digits.startsWith('4')) {
      brand = 'Visa';
    } else if (digits.startsWith('5') ||
        (digits.length >= 2 &&
            int.tryParse(digits.substring(0, 2)) != null &&
            int.parse(digits.substring(0, 2)) >= 51 &&
            int.parse(digits.substring(0, 2)) <= 55)) {
      brand = 'Mastercard';
    } else if (digits.startsWith('34') || digits.startsWith('37')) {
      brand = 'Amex';
    } else if (digits.startsWith('6')) {
      brand = 'Verve';
    }
    if (brand != _cardBrand) {
      setState(() => _cardBrand = brand);
    }
  }

  // ── STEP 1: Submit Card Details ───────────────────────────────────────────
  Future<void> _submitCardDetails() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final rawCard = _cardNumberCtrl.text.replaceAll(' ', '');
    final expiry = _expiryCtrl.text; // MM/YY
    final parts = expiry.split('/');
    final month = parts.isNotEmpty ? parts[0].trim() : '';
    final year = parts.length > 1 ? parts[1].trim() : '';
    final cvv = _cvvCtrl.text.trim();

    try {
      final data = await PaystackService.chargeCardDirectly(
        email: widget.email,
        amountInNaira: widget.amountInNaira,
        cardNumber: rawCard,
        cvv: cvv,
        expiryMonth: month,
        expiryYear: year,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (data == null) {
        setState(() => _errorMessage =
            'Could not reach Paystack server. Please check your internet connection.');
        return;
      }

      if (data['_error'] != null) {
        setState(() => _errorMessage = data['_error'].toString());
        return;
      }

      final cardStatus = data['status']?.toString() ?? '';
      _pendingReference = data['reference']?.toString() ?? '';

      if (cardStatus == 'success') {
        Navigator.pop(context, data);
        return;
      }

      if (cardStatus == 'send_pin') {
        setState(() {
          _currentStep = 2;
          _errorMessage = null;
        });
        return;
      }

      if (cardStatus == 'send_otp') {
        setState(() {
          _currentStep = 3;
          _otpDisplayText = data['display_text']?.toString() ??
              'Enter the OTP sent to your phone or email.';
          _errorMessage = null;
        });
        return;
      }

      if (cardStatus == 'pending' || cardStatus == 'pay_offline') {
        await _verifyPendingReference(_pendingReference);
        return;
      }

      setState(() => _errorMessage = data['message']?.toString() ??
          data['display_text']?.toString() ??
          'Card authorization failed. Please check your card details.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'An error occurred: ${e.toString()}';
        });
      }
    }
  }

  // ── STEP 2: Submit PIN ────────────────────────────────────────────────────
  Future<void> _submitPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Please enter your complete 4-digit PIN.');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final data = await PaystackService.submitChargePin(
        reference: _pendingReference,
        pin: pin,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (data == null) {
        setState(() => _errorMessage = 'Network error while submitting PIN. Try again.');
        return;
      }

      if (data['_error'] != null) {
        setState(() => _errorMessage = data['_error'].toString());
        return;
      }

      final status = data['status']?.toString() ?? '';
      if (data['reference'] != null && data['reference'].toString().isNotEmpty) {
        _pendingReference = data['reference'].toString();
      }

      if (status == 'success') {
        Navigator.pop(context, data);
        return;
      }

      if (status == 'send_otp') {
        setState(() {
          _currentStep = 3;
          _otpDisplayText = data['display_text']?.toString() ??
              'Enter the OTP sent to your phone or email.';
          _errorMessage = null;
        });
        return;
      }

      setState(() => _errorMessage = data['display_text']?.toString() ??
          data['message']?.toString() ??
          'PIN verification failed. Please try again.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error verifying PIN: ${e.toString()}';
        });
      }
    }
  }

  // ── STEP 3: Submit OTP ────────────────────────────────────────────────────
  Future<void> _submitOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      setState(() => _errorMessage = 'Please enter a valid OTP code.');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final data = await PaystackService.submitChargeOtp(
        reference: _pendingReference,
        otp: otp,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (data == null) {
        setState(() => _errorMessage = 'Network error while submitting OTP. Try again.');
        return;
      }

      if (data['_error'] != null) {
        setState(() => _errorMessage = data['_error'].toString());
        return;
      }

      final status = data['status']?.toString() ?? '';
      if (status == 'success') {
        Navigator.pop(context, data);
        return;
      }

      setState(() => _errorMessage = data['display_text']?.toString() ??
          data['message']?.toString() ??
          'OTP verification failed. Please try again.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error verifying OTP: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _verifyPendingReference(String ref) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    final verified = await PaystackService.verifyTransaction(ref);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (verified != null && verified['status'] == 'success') {
      Navigator.pop(context, verified);
    } else {
      setState(() => _errorMessage =
          'Payment is pending verification. Please try again in a few moments.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedText = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final purple = AppTheme.primaryPurpleFor(isDark);
    final inputFill = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Top Handle Bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Dynamic Step Views
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == 1
                  ? _buildStep1CardDetails(
                      primaryText: primaryText,
                      mutedText: mutedText,
                      purple: purple,
                      inputFill: inputFill,
                      borderColor: borderColor,
                      isDark: isDark,
                    )
                  : _currentStep == 2
                      ? _buildStep2PinInput(
                          primaryText: primaryText,
                          mutedText: mutedText,
                          purple: purple,
                          inputFill: inputFill,
                          borderColor: borderColor,
                          isDark: isDark,
                        )
                      : _buildStep3OtpInput(
                          primaryText: primaryText,
                          mutedText: mutedText,
                          purple: purple,
                          inputFill: inputFill,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
            ),
          ],
        ),
      ),
    );
  }


  // ── STEP 1: CARD DETAILS VIEW ─────────────────────────────────────────────
  Widget _buildStep1CardDetails({
    required Color primaryText,
    required Color mutedText,
    required Color purple,
    required Color inputFill,
    required Color borderColor,
    required bool isDark,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Add Card',
              style: TextStyle(
                fontSize: AppTypography.font(22),
                fontWeight: FontWeight.w800,
                color: primaryText,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Card Number
          _FieldLabel(label: 'Card Number', color: mutedText),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _cardNumberCtrl,
            focusNode: _cardNumberFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            maxLength: 19,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              color: primaryText,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
            decoration: _inputDecoration(
              hint: '0000  0000  0000  0000',
              isDark: isDark,
              inputFill: inputFill,
              borderColor: borderColor,
              purple: purple,
              suffix: _cardBrand.isEmpty
                  ? Icon(LucideIcons.creditCard, color: mutedText, size: 20.sp)
                  : _CardBrandBadge(brand: _cardBrand, purple: purple),
              counterText: '',
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(' ', '');
              if (digits.length < 13) return 'Enter a valid card number';
              return null;
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_expiryFocus),
          ),
          SizedBox(height: 16.h),

          // Expiry & CVV
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'Expiry Date', color: mutedText),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _expiryCtrl,
                      focusNode: _expiryFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                      ],
                      maxLength: 5,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      decoration: _inputDecoration(
                        hint: 'MM/YY',
                        isDark: isDark,
                        inputFill: inputFill,
                        borderColor: borderColor,
                        purple: purple,
                        counterText: '',
                      ),
                      validator: (v) {
                        if ((v ?? '').length < 5) return 'Invalid';
                        final parts = v!.split('/');
                        final month = int.tryParse(parts[0]);
                        if (month == null || month < 1 || month > 12) {
                          return 'Invalid month';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_cvvFocus),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'CVV', color: mutedText),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _cvvCtrl,
                      focusNode: _cvvFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: 4,
                      obscureText: _obscureCvv,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        hint: '•••',
                        isDark: isDark,
                        inputFill: inputFill,
                        borderColor: borderColor,
                        purple: purple,
                        counterText: '',
                        suffix: GestureDetector(
                          onTap: () =>
                              setState(() => _obscureCvv = !_obscureCvv),
                          child: Icon(
                            _obscureCvv
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            color: mutedText,
                            size: 18.sp,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '').length < 3) return 'Invalid';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context)
                          .requestFocus(_cardNameFocus),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Cardholder Name
          _FieldLabel(label: 'Cardholder Name', color: mutedText),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _cardNameCtrl,
            focusNode: _cardNameFocus,
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.name,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
              color: primaryText,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              hint: 'Name on card',
              isDark: isDark,
              inputFill: inputFill,
              borderColor: borderColor,
              purple: purple,
            ),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Enter cardholder name';
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitCardDetails(),
          ),
          SizedBox(height: 20.h),

          // Error alert box
          if (_errorMessage != null) ...[
            _buildErrorBox(_errorMessage!),
            SizedBox(height: 16.h),
          ],

          Center(
            child: Text(
              'Your card details are securely processed by Paystack.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                color: mutedText,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _submitCardDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: purple.withValues(alpha: 0.5),
                minimumSize: Size(double.infinity, 56.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Add Card',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 10.h),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: PIN INPUT VIEW ────────────────────────────────────────────────
  Widget _buildStep2PinInput({
    required Color primaryText,
    required Color mutedText,
    required Color purple,
    required Color inputFill,
    required Color borderColor,
    required bool isDark,
  }) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.keyRound, color: purple, size: 26.sp),
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: Text(
            'Enter Card PIN',
            style: TextStyle(
              fontSize: AppTypography.font(22),
              fontWeight: FontWeight.w800,
              color: primaryText,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Center(
          child: Text(
            'Your card issuer requires your 4-digit card PIN to authorize this card.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodySmall),
              color: mutedText,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 24.h),

        _FieldLabel(label: '4-Digit Card PIN', color: mutedText),
        SizedBox(height: 8.h),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: _obscurePin,
          maxLength: 4,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: AppTypography.font(20),
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: primaryText,
          ),
          textAlign: TextAlign.center,
          decoration: _inputDecoration(
            hint: '••••',
            isDark: isDark,
            inputFill: inputFill,
            borderColor: borderColor,
            purple: purple,
            counterText: '',
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePin = !_obscurePin),
              child: Icon(
                _obscurePin ? LucideIcons.eyeOff : LucideIcons.eye,
                color: mutedText,
                size: 20.sp,
              ),
            ),
          ),
          onSubmitted: (_) => _submitPin(),
        ),
        SizedBox(height: 20.h),

        if (_errorMessage != null) ...[
          _buildErrorBox(_errorMessage!),
          SizedBox(height: 16.h),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _submitPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: purple.withValues(alpha: 0.5),
              minimumSize: Size(double.infinity, 56.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999.r),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Authorize PIN',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 12.h),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _currentStep = 1;
                _errorMessage = null;
              });
            },
            icon: Icon(LucideIcons.arrowLeft, size: 16.sp, color: mutedText),
            label: Text(
              'Back to Card Details',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                color: mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 3: OTP INPUT VIEW ────────────────────────────────────────────────
  Widget _buildStep3OtpInput({
    required Color primaryText,
    required Color mutedText,
    required Color purple,
    required Color inputFill,
    required Color borderColor,
    required bool isDark,
  }) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.shieldCheck, color: purple, size: 26.sp),
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: Text(
            'OTP Verification',
            style: TextStyle(
              fontSize: AppTypography.font(22),
              fontWeight: FontWeight.w800,
              color: primaryText,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Center(
          child: Text(
            _otpDisplayText.isNotEmpty
                ? _otpDisplayText
                : 'Enter the verification code sent by your bank to complete registration.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.bodySmall),
              color: mutedText,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 24.h),

        _FieldLabel(label: 'Verification OTP Code', color: mutedText),
        SizedBox(height: 8.h),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: AppTypography.font(20),
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: primaryText,
          ),
          textAlign: TextAlign.center,
          decoration: _inputDecoration(
            hint: '••••••',
            isDark: isDark,
            inputFill: inputFill,
            borderColor: borderColor,
            purple: purple,
            counterText: '',
          ),
          onSubmitted: (_) => _submitOtp(),
        ),
        SizedBox(height: 20.h),

        if (_errorMessage != null) ...[
          _buildErrorBox(_errorMessage!),
          SizedBox(height: 16.h),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _submitOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: purple.withValues(alpha: 0.5),
              minimumSize: Size(double.infinity, 56.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999.r),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Verify & Save Card',
                    style: TextStyle(
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 12.h),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _currentStep = 1;
                _errorMessage = null;
              });
            },
            icon: Icon(LucideIcons.arrowLeft, size: 16.sp, color: mutedText),
            label: Text(
              'Back to Card Details',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                color: mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ERROR ALERT BOX ───────────────────────────────────────────────────────
  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleX, color: Colors.red, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    required Color inputFill,
    required Color borderColor,
    required Color purple,
    Widget? suffix,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[600] : Colors.grey[400],
        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      filled: true,
      fillColor: inputFill,
      suffixIcon: suffix != null
          ? Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: suffix,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(),
      counterText: counterText,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _FieldLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppTypography.font(AppFontSizes.caption),
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _CardBrandBadge extends StatelessWidget {
  final String brand;
  final Color purple;
  const _CardBrandBadge({required this.brand, required this.purple});

  @override
  Widget build(BuildContext context) {
    IconData icon = LucideIcons.creditCard;
    Color color;
    switch (brand) {
      case 'Visa':
        color = const Color(0xFF1A1F71);
        break;
      case 'Mastercard':
        color = const Color(0xFFEB001B);
        break;
      case 'Amex':
        color = const Color(0xFF007BC1);
        break;
      default:
        color = purple;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18.sp),
        SizedBox(width: 4.w),
        Text(
          brand,
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.caption),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
