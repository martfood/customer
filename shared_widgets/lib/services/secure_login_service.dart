import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Thrown when the server refuses a login because the account is locked
/// (progressive lockout) or the caller's IP is rate-limited.
class LoginLockedException implements Exception {
  /// 1-4 for account lockouts, 0 for IP blocks.
  final int stage;
  final bool indefinite;
  final bool ipBlocked;
  final int remainingSec;
  final String supportEmail;

  const LoginLockedException({
    required this.stage,
    required this.indefinite,
    required this.ipBlocked,
    required this.remainingSec,
    required this.supportEmail,
  });

  @override
  String toString() => 'LoginLockedException(stage: $stage, indefinite: $indefinite, ipBlocked: $ipBlocked)';
}

/// Single entry point for password logins across customer and rider apps.
///
/// Lockout and IP rate limiting are enforced by the `secureLogin` Cloud
/// Function; this client only forwards credentials and signs in with the
/// custom token the server returns. It never falls back to direct
/// `signInWithEmailAndPassword`, so the server rules cannot be bypassed here.
class SecureLoginService {
  static const String _endpoint =
      'https://europe-west1-martfood-app.cloudfunctions.net/secureLogin';
  static const String _fallbackSupportEmail = 'support@martfooddelivery.com';

  /// [app] is one of `customer`, `rider`, `vendor`, `admin`.
  static Future<UserCredential> signIn({
    required String email,
    required String password,
    required String app,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password, 'app': app}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw FirebaseAuthException(code: 'network-request-failed');
    } catch (_) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    switch (response.statusCode) {
      case 200:
        final token = body['token'] as String?;
        if (token == null || token.isEmpty) {
          throw FirebaseAuthException(code: 'internal-error');
        }
        return FirebaseAuth.instance.signInWithCustomToken(token);
      case 401:
        // Same code Firebase uses, so existing AuthErrorHandler messages apply.
        throw FirebaseAuthException(code: 'invalid-credential');
      case 403:
        throw FirebaseAuthException(code: 'user-disabled');
      case 423:
      case 429:
        final ip = body['code'] == 'ip_blocked';
        throw LoginLockedException(
          stage: ip ? 0 : ((body['stage'] as num?)?.toInt() ?? 1),
          indefinite: body['indefinite'] == true,
          ipBlocked: ip,
          remainingSec: ((ip ? body['retryAfterSec'] : body['remainingSec']) as num?)?.toInt() ?? 0,
          supportEmail: (body['supportEmail'] as String?) ?? _fallbackSupportEmail,
        );
      default:
        throw FirebaseAuthException(code: 'internal-error');
    }
  }
}

