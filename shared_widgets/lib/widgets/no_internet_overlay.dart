import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Global controller to manually query or toggle connectivity state
class ConnectivityController extends ChangeNotifier {
  static final ConnectivityController instance = ConnectivityController._();
  ConnectivityController._();

  bool _isDisconnected = false;
  bool get isDisconnected => _isDisconnected;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  Timer? _pingTimer;

  void initialize() {
    // Initial check
    checkConnectivity();

    // Periodic heartbeat verification every 5 seconds
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    _isChecking = true;
    notifyListeners();

    try {
      // 100% Reliable socket lookup to check true internet reachability
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        _setDisconnected(false);
        _isChecking = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      try {
        // Fallback socket lookup to Cloudflare DNS (1.1.1.1)
        final socket = await Socket.connect('1.1.1.1', 53,
            timeout: const Duration(seconds: 3));
        socket.destroy();
        _setDisconnected(false);
        _isChecking = false;
        notifyListeners();
        return true;
      } catch (_) {
        _setDisconnected(true);
      }
    }

    _isChecking = false;
    notifyListeners();
    return !_isDisconnected;
  }

  void _setDisconnected(bool value) {
    if (_isDisconnected != value) {
      _isDisconnected = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }
}

/// Global Connectivity Wrapper widget to wrap MaterialApp or top screen tree.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onGoHome;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.onGoHome,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final _controller = ConnectivityController.instance;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _controller.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isDisconnected)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: NoInternetOverlay(
                onGoHome: widget.onGoHome,
              ),
            ),
          ),
      ],
    );
  }
}

/// Full screen Minimal & Flat "No Internet Connection" overlay matching reference design
class NoInternetOverlay extends StatefulWidget {
  final VoidCallback? onGoHome;
  final VoidCallback? onBackPressed;

  const NoInternetOverlay({
    super.key,
    this.onGoHome,
    this.onBackPressed,
  });

  @override
  State<NoInternetOverlay> createState() => _NoInternetOverlayState();
}

class _NoInternetOverlayState extends State<NoInternetOverlay> {
  bool _isRetrying = false;

  Future<void> _handleTryAgain() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    final restored = await ConnectivityController.instance.checkConnectivity();

    if (mounted) {
      setState(() => _isRetrying = false);
      if (!restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still no internet connection. Please check your network settings.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF71717A);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final lightPurpleBg = isDark
        ? AppTheme.darkPrimaryPurple.withValues(alpha: 0.15)
        : const Color(0xFFF3E8FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 500,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Soft Light Purple Circle with WifiOff Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lightPurpleBg,
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.wifiOff,
                        size: 48,
                        color: purpleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Title
                  Text(
                    'No internet connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(20),
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w400,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Try Again Button (Primary Pill Button)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isRetrying ? null : _handleTryAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: AppTypography.font(16),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
