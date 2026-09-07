import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/custom_snackbar.dart';

class AuthErrorHandler {
  /// Maps any caught exception to a user-friendly error message.
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return 'No internet access. Please verify you have an active data plan or working Wi-Fi connection.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password. Please verify and try again.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'email-already-in-use':
          return 'This email address is already in use by another account.';
        case 'weak-password':
          return 'The password is too weak. Please use at least 6 characters with numbers or symbols.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'operation-not-allowed':
          return 'This sign-in method is currently disabled. Please contact support.';
        default:
          return error.message ?? 'An authentication error occurred. Please try again.';
      }
    }

    if (error is FirebaseException) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Connection timeout. Please verify you have an active internet connection or data plan.';
      }
      return error.message ?? 'A database error occurred. Please try again.';
    }

    if (error is SocketException) {
      return 'No internet access. Please verify you have an active data plan or working Wi-Fi connection.';
    }

    if (error is TimeoutException) {
      return 'Connection timed out. Please check your data plan or network strength and try again.';
    }

    if (error is HttpException || error.toString().contains('ClientException') || error.toString().contains('SocketException')) {
      return 'No internet access. Please verify you have an active data plan or working Wi-Fi connection.';
    }

    final errorString = error.toString().toLowerCase();

    // Google Sign-In / PlatformException mapping
    if (errorString.contains('sign_in_failed') || errorString.contains('api.j: 10') || errorString.contains('apiexception: 10')) {
      return 'Google Sign-In configuration mismatch (SHA-1 missing in Firebase). Please verify Play Store signing key or sign in with email.';
    }

    if (errorString.contains('sign_in_canceled') || errorString.contains('sign_in_cancelled')) {
      return 'Google Sign-In was cancelled.';
    }

    // Default error string parsing/fallback
    if (errorString.contains('socketexception') || 
        errorString.contains('network') || 
        errorString.contains('failed host lookup') || 
        errorString.contains('timeout') || 
        errorString.contains('timed out') || 
        errorString.contains('connection refused')) {
      return 'No internet access. Please verify you have an active data plan or working Wi-Fi connection.';
    }

    return error.toString().replaceAll('Exception:', '').replaceAll('PlatformException', '').trim();
  }

  /// Displays the error in a styled modern Floating SnackBar with appropriate icons.
  static void showError(BuildContext context, dynamic error) {
    final message = getErrorMessage(error);

    // Detect if this is a network issue to show the appropriate icon
    final isNetwork = message.contains('internet') || message.contains('connection') || message.contains('network');

    CustomSnackBar.show(
      context,
      message: message,
      type: isNetwork ? SnackBarType.warning : SnackBarType.error,
      duration: const Duration(seconds: 4),
    );
  }
}
