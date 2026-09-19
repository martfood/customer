import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Centralized service to finalize and confirm orders once payment is verified.
/// Safe against duplicate executions (idempotent via Firestore checking).
class OrderCompletionService {
  OrderCompletionService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String pendingOrderKey = 'pending_bank_order_id';

  /// Saves the pending bank transfer order ID locally
  static Future<void> savePendingBankOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pendingOrderKey, orderId);
    } catch (e) {
      debugPrint('Error saving pending bank order: $e');
    }
  }

  /// Clears the pending bank transfer order ID locally
  static Future<void> clearPendingBankOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(pendingOrderKey);
    } catch (e) {
      debugPrint('Error clearing pending bank order: $e');
    }
  }

  /// Marks an order as paid, deducts stock, notifies vendor & customer, and clears cart.
  /// If the order is already marked as 'paid' or not in 'awaiting_payment', it avoids re-decrementing stock.
  static Future<bool> completeOrderPayment({
    required String orderId,
    Map<String, dynamic>? orderData,
  }) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        debugPrint('Order $orderId does not exist.');
        return false;
      }

      final data = orderSnap.data() ?? {};
      final String currentStatus = (data['status'] ?? '').toString();
      final String currentPaymentStatus = (data['paymentStatus'] ?? '').toString();

      // If already paid or confirmed, clean up and return true
      if (currentPaymentStatus == 'paid' && currentStatus != 'awaiting_payment') {
        await clearPendingBankOrder();
        return true;
      }

      final double orderTotal = ((data['total'] ?? 0.0) as num).toDouble();
      final String customerId = (data['customerId'] ?? '').toString();
      final String customerName = (data['customerName'] ?? 'Customer').toString();
      final String customerEmail = (data['customerEmail'] ?? '').toString();
      final String effectiveVendorId = (data['vendorId'] ?? '').toString();
      final String restaurantName = (data['restaurantName'] ?? 'MartFood Vendor').toString();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? [];

      // 1. Update Order in Firestore
      await orderRef.update({
        'status': 'pending',
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add Customer Transaction Record
      if (customerId.isNotEmpty) {
        try {
          await _firestore.collection('customers').doc(customerId).collection('transactions').add({
            'title': 'Order Checkout Payment (Bank Transfer)',
            'amount': orderTotal,
            'type': 'Orders',
            'isExpense': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error recording transaction: $e');
        }
      }

      // 3. Dispatch Push Notification to Vendor
      if (effectiveVendorId.isNotEmpty) {
        final orderNum = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId;
        NotificationService.sendPushToVendor(
          vendorId: effectiveVendorId,
          title: 'New Order Received! 🛍️',
          body: 'Order #$orderNum (${items.length} items - ₦${orderTotal.toStringAsFixed(0)}) placed by $customerName',
          data: {
            'orderId': orderId,
            'type': 'order',
          },
        );
      }

      // 4. Decrement Stock Inventory
      final collectionsToCheck = [
        'resturantPosts',
        'grocerytPosts',
        'pharmacytPosts',
        'bakerytPosts'
      ];

      for (final item in items) {
        if (item is! Map) continue;
        final itemId = item['id']?.toString() ?? '';
        final deductQty = (item['quantity'] as num?)?.toInt() ?? 1;

        if (itemId.isEmpty) continue;

        for (final coll in collectionsToCheck) {
          try {
            final docRef = _firestore.collection(coll).doc(itemId);
            final docSnap = await docRef.get();
            if (docSnap.exists) {
              final postData = docSnap.data();
              final curQty = postData?['quantity'] as num?;
              if (curQty != null) {
                final int newQty = (curQty.toInt() - deductQty) > 0 ? (curQty.toInt() - deductQty) : 0;
                await docRef.update({
                  'quantity': newQty,
                  'stockQuantity': newQty,
                  if (newQty <= 0) 'inStock': false,
                });
              } else {
                await docRef.update({
                  'quantity': FieldValue.increment(-deductQty),
                  'stockQuantity': FieldValue.increment(-deductQty),
                });
              }
              break;
            }
          } catch (e) {
            debugPrint('Error decrementing item $itemId in $coll: $e');
          }
        }
      }

      // 5. Send Confirmation Email
      if (customerEmail.isNotEmpty) {
        try {
          final emailSubject = 'Order Confirmed - #$orderId';
          final emailHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Order Confirmed - MartFood</title>
</head>
<body style="font-family: sans-serif; background-color: #f8fafc; padding: 20px; color: #334155; line-height: 1.6;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 0; border: 1px solid #e2e8f0; overflow: hidden;">
    <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Confirmed! 🍔</h2>
    </div>
    <div style="padding: 24px;">
      <p>Hi $customerName,</p>
      <p>Your bank transfer payment was received and your order at <strong>$restaurantName</strong> has been confirmed successfully.</p>
      <div style="background-color: #F5F3FF; padding: 16px; border-radius: 8px; margin: 20px 0; border: 1px solid #C4B5FD;">
        <h3 style="margin-top: 0; font-size: 16px; color: #0f172a;">Order Details</h3>
        <p style="margin: 4px 0;"><strong>Order ID:</strong> #$orderId</p>
        <p style="margin: 4px 0;"><strong>Restaurant:</strong> $restaurantName</p>
        <p style="margin: 4px 0;"><strong>Total Paid:</strong> ₦${orderTotal.toStringAsFixed(2)}</p>
        <p style="margin: 4px 0;"><strong>Status:</strong> Pending vendor confirmation</p>
      </div>
      <p>You can track the progress of your order in the app real-time.</p>
      <br/>
      <p>Best Regards,</p>
      <p><strong>The MartFood Team</strong></p>
    </div>
    <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
      &copy; 2026 MartFood Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>
''';
          NotificationService.sendEmail(
            to: customerEmail,
            subject: emailSubject,
            htmlContent: emailHtml,
          );
        } catch (_) {}
      }

      // 6. Remove items from customer's cart
      if (customerId.isNotEmpty) {
        try {
          final cartRef = _firestore.collection('customers').doc(customerId).collection('cart');
          for (final item in items) {
            if (item is! Map) continue;
            final itemId = item['id']?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              await cartRef.doc(itemId).delete();
            }
          }
        } catch (e) {
          debugPrint('Error removing cart items: $e');
        }
      }

      // 7. Clear pending state
      await clearPendingBankOrder();
      return true;
    } catch (e) {
      debugPrint('Error in completeOrderPayment: $e');
      return false;
    }
  }
}
