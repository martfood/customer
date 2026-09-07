import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'paystack_service.dart';

class PaystackWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final Function(Map<String, dynamic> verifyResponse) onSuccess;
  final VoidCallback onCancel;

  const PaystackWebViewScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaystackWebViewScreen> createState() => _PaystackWebViewScreenState();
}

class _PaystackWebViewScreenState extends State<PaystackWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Auto verify if we land on custom callback or redirect
            if (url.contains("callback") || url.contains("success") || url.contains("close")) {
              _verifyAndFinish();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.contains("callback") || url.contains("success") || url.contains("close")) {
              _verifyAndFinish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  Future<void> _verifyAndFinish() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final res = await PaystackService.verifyTransaction(widget.reference);
    if (!mounted) return;

    if (res != null && res['status'] == 'success') {
      widget.onSuccess(res);
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close, color: purpleColor, size: 20.sp),
              onPressed: _verifyAndFinish,
            ),
          ),
        ),
        title: Text(
          'Paystack Checkout',
          style: TextStyle(
            color: purpleColor,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: purpleColor,
              ),
            ),
        ],
      ),
    );
  }
}
