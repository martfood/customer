import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_widgets/widgets/app_update_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static const String customerAppVersion = '1.0.0+2';
  static bool _hasPromptedThisSession = false;
  static dynamic _lastHandledTimestamp;
  static bool _isSheetVisible = false;
  static StreamSubscription<DocumentSnapshot>? _subscription;

  /// Compares two semver strings, supporting Flutter build numbers (e.g. "1.0.0+3" vs "1.0.0+2" or "1.1.0" vs "1.0.0").
  /// Returns true if [remote] is strictly greater than [local].
  static bool isVersionNewer(String remote, String local) {
    if (remote.isEmpty || local.isEmpty) return false;
    try {
      final remoteVersion = remote.split('+')[0].trim();
      final localVersion = local.split('+')[0].trim();

      final remoteBuild = remote.contains('+')
          ? int.tryParse(remote.split('+')[1].trim()) ?? 0
          : 0;
      final localBuild = local.contains('+')
          ? int.tryParse(local.split('+')[1].trim()) ?? 0
          : 0;

      final remoteParts =
          remoteVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final localParts =
          localVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = remoteParts.length > localParts.length
          ? remoteParts.length
          : localParts.length;

      for (int i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }

      // If version numbers are identical (e.g. 1.0.0 vs 1.0.0), compare build numbers if remote specified one
      if (remote.contains('+')) {
        return remoteBuild > localBuild;
      }

      return false;
    } catch (e) {
      debugPrint('Error parsing semver: $e');
      return false;
    }
  }

  /// Evaluates update data and presents the popup dialog if applicable
  static void _evaluateAndPrompt(
    BuildContext context,
    Map<String, dynamic> data,
    String currentVersion,
  ) async {
    try {
      final bool enabled = data['enabled'] == true;
      if (!enabled) {
        // If disabled by admin while open, close it
        if (_isSheetVisible && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _isSheetVisible = false;
        }
        return;
      }

      final String latestVersion = (data['latestVersion'] ?? '').toString().trim();
      final String minVersion = (data['minVersion'] ?? '').toString().trim();
      final bool isMandatorySetting = data['isMandatory'] == true;

      // If installed app is already strictly higher than latestVersion, no update is needed
      final bool isAlreadyHigher =
          latestVersion.isNotEmpty && isVersionNewer(currentVersion, latestVersion);
      if (isAlreadyHigher && !isMandatorySetting) {
        return;
      }

      final bool isBelowMin =
          minVersion.isNotEmpty && isVersionNewer(minVersion, currentVersion);
      final bool isMandatory = isMandatorySetting || isBelowMin;

      final updatedAt = data['updatedAt'];
      final bool isNewAdminPublish =
          updatedAt != null && updatedAt != _lastHandledTimestamp;

      // If optional and already prompted during this session without an admin edit, avoid repeating
      if (!isMandatory && _hasPromptedThisSession && !isNewAdminPublish) {
        return;
      }

      if (_isSheetVisible) {
        // If already visible and mandatory status changed, we can let the user continue
        return;
      }

      final String title =
          (data['title'] ?? 'New Update Available! 🚀').toString();
      final String message = (data['message'] ??
              'A new version of MartFood is available with performance improvements and new features.')
          .toString();

      final rawNotes = data['releaseNotes'];
      final List<String> releaseNotes = (rawNotes is List)
          ? rawNotes
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [];

      final String androidUrl = (data['androidUrl'] ?? '').toString().trim();
      final String iosUrl = (data['iosUrl'] ?? '').toString().trim();

      String targetUrl = androidUrl;
      if (!kIsWeb && Platform.isIOS) {
        targetUrl = iosUrl.isNotEmpty ? iosUrl : androidUrl;
      }

      if (!context.mounted) return;
      _hasPromptedThisSession = true;
      _lastHandledTimestamp = updatedAt;
      _isSheetVisible = true;

      // Clear legacy snooze key
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('update_snooze_customer_app_$latestVersion');
      } catch (_) {}

      if (!context.mounted) return;

      AppUpdateSheet.show(
        context,
        latestVersion:
            latestVersion.isNotEmpty ? latestVersion : currentVersion,
        title: title,
        message: message,
        releaseNotes: releaseNotes,
        isMandatory: isMandatory,
        onUpdateNow: () async {
          if (targetUrl.isNotEmpty) {
            final uri = Uri.parse(targetUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            }
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not open store link. Please search for MartFood on your app store.'),
              ),
            );
          }
        },
        onRemindLater: () {
          _isSheetVisible = false;
          _hasPromptedThisSession = true;
        },
      ).then((_) {
        _isSheetVisible = false;
      });
    } catch (e) {
      debugPrint('Error evaluating customer app update: $e');
    }
  }

  /// Subscribes to real-time updates and also performs an immediate check
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    String currentVersion = customerAppVersion,
  }) async {
    try {
      _subscription?.cancel();
      _subscription = FirebaseFirestore.instance
          .collection('app_updates')
          .doc('customer_app')
          .snapshots()
          .listen((doc) {
        if (!doc.exists || !context.mounted) return;
        _evaluateAndPrompt(context, doc.data() ?? {}, currentVersion);
      }, onError: (err) {
        debugPrint('Error listening to customer app update doc: $err');
      });
    } catch (e) {
      debugPrint('Error checking for customer app update: $e');
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
