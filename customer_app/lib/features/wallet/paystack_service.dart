import 'dart:convert';
import 'package:http/http.dart' as http;

class PaystackService {
  static const String secretKey =
      "sk_live_03d60c86bbc46509fd966904e40ad248c015c790";
  static const String publicKey =
      "pk_live_9a3133bdb8c6539b8ba228059dde0a4f10df3e1a";

  /// Initialize transaction with optional channel override (e.g. ['bank_transfer'])
  static Future<Map<String, dynamic>?> initializeTransaction({
    required String email,
    required double amountInNaira,
    List<String>? channels,
  }) async {
    final url = Uri.parse("https://api.paystack.co/transaction/initialize");
    final amountInKobo = (amountInNaira * 100).toInt();

    final body = {
      'email': email,
      'amount': amountInKobo.toString(),
      if (channels != null) 'channels': channels,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return data['data'];
        }
      }
      print(
          "Paystack initialize error: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Exception inside Paystack initialize: $e");
    }
    return null;
  }

  /// Create a dynamic bank transfer virtual account via Paystack Charge API.
  ///
  /// Uses POST /charge with bank_transfer object — this is the ONLY Paystack
  /// endpoint that returns a real temporary NUBAN (account_number + bank name).
  /// The old /transaction/initialize never returns those fields.
  static Future<Map<String, dynamic>?> createBankTransferAccount({
    required String email,
    required double amountInNaira,
  }) async {
    final url = Uri.parse("https://api.paystack.co/charge");
    final amountInKobo = (amountInNaira * 100).toInt();

    final body = {
      'email': email,
      'amount': amountInKobo,
      'bank_transfer': {
        'account_expires_at':
            DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String(),
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print("Paystack Charge response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];

        if (data != null) {
          final reference = (data['reference'] ?? '').toString();

          // Paystack Charge API returns account details directly in data
          final accountNumber = data['account_number']?.toString() ??
              data['bank']?['account_number']?.toString();
          final bankName = data['bank']?['name']?.toString() ??
              data['bank_name']?.toString();
          final accountName =
              data['account_name']?.toString() ?? data['business_name']?.toString();

          if (accountNumber != null && bankName != null) {
            return {
              'bank_name': bankName,
              'account_name': accountName ?? email,
              'account_number': accountNumber,
              'reference': reference.isNotEmpty
                  ? reference
                  : 'TRF_${DateTime.now().millisecondsSinceEpoch}',
            };
          }
        }
      }
      print("Paystack charge error: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Exception inside Paystack createBankTransferAccount: $e");
    }

    // Fallback: generate a reference and show a manual transfer notice
    return null;
  }

  /// Verify a transaction
  static Future<Map<String, dynamic>?> verifyTransaction(
      String reference) async {
    final url =
        Uri.parse("https://api.paystack.co/transaction/verify/$reference");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return data['data'];
        }
      }
      print("Paystack verify error: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Exception inside Paystack verify: $e");
    }
    return null;
  }

  /// Charge a saved card signature
  static Future<bool> chargeSavedCard({
    required String email,
    required double amountInNaira,
    required String authorizationCode,
  }) async {
    final url =
        Uri.parse("https://api.paystack.co/transaction/charge_authorization");
    final amountInKobo = (amountInNaira * 100).toInt();

    final body = {
      'email': email,
      'amount': amountInKobo.toString(),
      'authorization_code': authorizationCode,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data']['status'] == 'success') {
          return true;
        }
      }
      print(
          "Paystack charge authorization error: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Exception charging authorization: $e");
    }
    return false;
  }

  /// Charge a card directly via Paystack Charge API (PCI-DSS path).
  ///
  /// Sends card number, CVV, expiry month/year to POST /charge.
  /// Returns the full `data` map on success (contains `authorization.authorization_code`,
  /// `authorization.last4`, `authorization.brand`, etc.).
  /// Returns null on network failure. Returns {'_error': message} on card decline.
  static Future<Map<String, dynamic>?> chargeCardDirectly({
    required String email,
    required double amountInNaira,
    required String cardNumber,
    required String cvv,
    required String expiryMonth,
    required String expiryYear,
  }) async {
    final url = Uri.parse("https://api.paystack.co/charge");
    final amountInKobo = (amountInNaira * 100).toInt();

    final body = {
      'email': email,
      'amount': amountInKobo,
      'card': {
        'number': cardNumber.replaceAll(' ', ''),
        'cvv': cvv,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print("Paystack ChargeCard response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
        print("Paystack ChargeCard failed: ${decoded['message']}");
        return {'_error': decoded['message'] ?? 'Card charge failed'};
      }
      print("Paystack ChargeCard HTTP error: ${response.statusCode} - ${response.body}");
    } catch (e) {
      print("Exception inside Paystack chargeCardDirectly: $e");
    }
    return null;
  }

  /// Submit OTP for an ongoing Paystack card charge.
  /// Called when chargeCardDirectly returns status == 'send_otp'.
  static Future<Map<String, dynamic>?> submitChargeOtp({
    required String reference,
    required String otp,
  }) async {
    final url = Uri.parse("https://api.paystack.co/charge/submit_otp");
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reference': reference, 'otp': otp}),
      );
      print("Paystack submitOtp: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
        return {'_error': decoded['message'] ?? 'OTP submission failed'};
      }
    } catch (e) {
      print("Exception in Paystack submitChargeOtp: $e");
    }
    return null;
  }

  /// Submit PIN for an ongoing Paystack card charge.
  /// Called when chargeCardDirectly returns status == 'send_pin'.
  static Future<Map<String, dynamic>?> submitChargePin({
    required String reference,
    required String pin,
  }) async {
    final url = Uri.parse("https://api.paystack.co/charge/submit_pin");
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reference': reference, 'pin': pin}),
      );
      print("Paystack submitPin: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
        return {'_error': decoded['message'] ?? 'PIN submission failed'};
      }
    } catch (e) {
      print("Exception in Paystack submitChargePin: $e");
    }
    return null;
  }
}
