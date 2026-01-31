# Fawaterk Payment Gateway Integration Guide

**For Flutter Developers** - Zuwad Academy Family Wallet Payment System

## Table of Contents
1. [Overview](#overview)
2. [API Configuration](#api-configuration)
3. [Creating an Invoice (Quick Invoice)](#creating-an-invoice-quick-invoice)
4. [Webhook Handling](#webhook-handling)
5. [Complete Payment Flow](#complete-payment-flow)
6. [Smart Balance Calculation](#smart-balance-calculation)
7. [Error Handling](#error-handling)
8. [Flutter Code Examples](#flutter-code-examples)

---

## Overview

The Zuwad Academy plugin uses Fawaterk payment gateway to process family wallet deposits. The integration uses the **Create Invoice Link** method to generate payment URLs that customers can use to pay via various methods (Credit Card, Fawry, Mobile Wallets, etc.).

### Key Features
- **Multi-currency support**: USD, EGP, SAR, AED, KWD, QAR, BHD, OMR, JOD, EUR, GBP, CAD, TRY, DZD, MAD, IQD, SDG, SYP, BAM, RON, MDL
- **Automatic balance updates** via webhook
- **Family wallet integration** with smart deposit handling
- **WhatsApp notifications** on successful payment

---

## API Configuration

### Base URL
```
Production: https://app.fawaterk.com/api/v2/createInvoiceLink
Staging: https://staging.fawaterk.com/api/v2/createInvoiceLink
```

### Authentication
```http
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

### API Key
```
a81aa852de53f0196680b87ccb2d43cd99080860a7be1fd548
```

---

## Creating an Invoice (Quick Invoice)

### Endpoint
```
POST https://app.fawaterk.com/api/v2/createInvoiceLink
```

### Request Headers
```http
Authorization: Bearer a81aa852de53f0196680b87ccb2d43cd99080860a7be1fd548
Content-Type: application/json
```

### Request Body

#### Basic Structure
```json
{
    "cartTotal": "100.00",
    "currency": "USD",
    "customer": {
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+201234567890",
        "email": "customer@example.com"
    },
    "cartItems": [
        {
            "name": "رسوم دراسية - زواد",
            "price": "100.00",
            "quantity": "1"
        }
    ],
    "redirectionUrls": {
        "successUrl": "https://zuwad-academy.com/payment-has-been-successfully-completed/",
        "failUrl": "https://zuwad-academy.com/payment-has-failed/",
        "pendingUrl": "https://zuwad-academy.com/payment-is-pending/",
        "webhookUrl": "https://system.zuwad-academy.com/wp-json/zuwad/v1/fawaterk-webhook_json"
    },
    "payLoad": {
        "family_id": 123,
        "phone": "+201234567890",
        "currency": "USD",
        "amount": 100.00
    }
}
```

### Parameters Reference

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cartTotal` | String | Yes | Total amount to be paid |
| `currency` | String | Yes | Currency code (USD, EGP, SAR, AED, etc.) |
| `customer` | Object | Yes | Customer information object |
| `customer.first_name` | String | Yes | Customer first name |
| `customer.last_name` | String | Yes | Customer last name |
| `customer.phone` | String | No | Customer phone number |
| `customer.email` | String | No | Customer email address |
| `cartItems` | Array | Yes | Array of items being purchased |
| `cartItems[].name` | String | Yes | Item name |
| `cartItems[].price` | String | Yes | Item price |
| `cartItems[].quantity` | String | Yes | Item quantity |
| `redirectionUrls` | Object | Yes | Redirect URLs after payment |
| `redirectionUrls.successUrl` | String | Yes | URL for successful payment |
| `redirectionUrls.failUrl` | String | Yes | URL for failed payment |
| `redirectionUrls.pendingUrl` | String | Yes | URL for pending payment |
| `redirectionUrls.webhookUrl` | String | Yes | Webhook endpoint for payment confirmation |
| `payLoad` | Object | No | Custom data for webhook (REQUIRED for auto-balance) |
| `payLoad.family_id` | Integer | Yes* | Family ID for wallet update |
| `payLoad.phone` | String | Yes* | Phone number from customer |
| `payLoad.currency` | String | Yes* | Payment currency |
| `payLoad.amount` | Float | Yes* | Payment amount |

### Success Response

```json
{
    "status": "success",
    "data": {
        "url": "https://app.fawaterk.com/link/ABC123",
        "invoiceId": 12345,
        "invoiceKey": "xyz789"
    }
}
```

### Error Response

```json
{
    "status": "error",
    "message": "Error description here"
}
```

---

## Webhook Handling

### Webhook Endpoint
```
POST https://system.zuwad-academy.com/wp-json/zuwad/v1/fawaterk-webhook_json
```

**Important**: The webhook URL must end with `_json` to receive JSON formatted data from Fawaterk.

### Webhook Request Body (Success - Paid)

```json
{
    "hashKey": "f59665d40772c9c47156cd0bff453b85e489306e849c27eea2",
    "invoice_key": "69zpnFIcIPYNBwG",
    "invoice_id": 1000430,
    "invoice_status": "paid",
    "payment_method": "Credit-Debit Card",
    "pay_load": {
        "family_id": 123,
        "phone": "+201234567890",
        "currency": "USD",
        "amount": 100.00
    },
    "referenceNumber": "982443480"
}
```

### Webhook Request Body (Failed)

```json
{
    "invoice_key": "P4Xe5sQpFzRIwzq",
    "invoice_id": 281795,
    "payment_method": "Card",
    "pay_load": {
        "family_id": 123,
        "phone": "+201234567890",
        "currency": "USD",
        "amount": 100.00
    },
    "amount": 1000,
    "paidCurrency": "EGP",
    "errorMessage": "3D Secure authentication failed",
    "response": {
        "gatewayCode": "DECLINED",
        "gatewayRecommendation": "PROCEED"
    },
    "referenceNumber": ""
}
```

### Webhook Processing Flow

1. **Validation**: Check for required fields (`invoice_id`, `invoice_status`)
2. **Status Check**: Only process invoices with status `"paid"`
3. **Duplicate Prevention**: Check if invoice was already processed using `reference_id = 'fawaterk_invoice'`
4. **Family Verification**: Validate family exists in database
5. **Smart Balance Calculation**: Apply threshold-based deposit logic
6. **Database Updates**: Create transaction record and update wallet balance
7. **WhatsApp Notification**: Send payment confirmation to family members

### Webhook Response (Success)

```json
{
    "status": "success",
    "message": "Balance updated successfully",
    "transaction_id": 54321,
    "family_id": 123,
    "amount": 100.00
}
```

### Webhook Response (Already Processed)

```json
{
    "status": "already_processed",
    "message": "Invoice already processed"
}
```

### Webhook Response (Error)

```json
{
    "status": "error",
    "message": "Error description"
}
```

---

## Complete Payment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PAYMENT FLOW DIAGRAM                                │
└─────────────────────────────────────────────────────────────────────────────┘

1. USER INITIATES PAYMENT
   │
   ├── Flutter App: User clicks "Pay" button
   │
   └── Triggers createQuickInvoice() function

2. CONFIRMATION DIALOG
   │
   ├── Shows: Student name, phone, amount
   │
   └── User confirms → Proceed to step 3

3. CREATE INVOICE API REQUEST
   │
   ├── POST to Fawaterk API
   │   ├── URL: https://app.fawaterk.com/api/v2/createInvoiceLink
   │   ├── Headers: Authorization Bearer token, Content-Type
   │   └── Body: customer info, amount, currency, payLoad
   │
   └── Fawaterk returns: payment URL, invoice ID, invoice key

4. DISPLAY PAYMENT OPTIONS
   │
   ├── Show payment URL to user
   │   ├── Copy link button
   │   └── Open link button
   │
   └── User opens payment link

5. CUSTOMER COMPLETES PAYMENT
   │
   ├── Fawaterk payment page
   │   ├── Select payment method (Visa/Mastercard, Fawry, etc.)
   │   ├── Enter payment details
   │   └── Submit payment
   │
   └── Payment processed

6. FAWATERK SENDS WEBHOOK
   │
   ├── POST to webhook URL
   │   └── https://system.zuwad-academy.com/wp-json/zuwad/v1/fawaterk-webhook_json
   │
   └── Server processes payment confirmation

7. SERVER PROCESSES PAYMENT
   │
   ├── Validates webhook data
   ├── Checks for duplicates
   ├── Updates family wallet balance (smart calculation)
   ├── Creates transaction record
   ├── Logs activity
   └── Sends WhatsApp notification

8. CUSTOMER NOTIFICATION
   │
   └── Family members receive WhatsApp: "تم اضافة رصيد X YYY الى حسابك بنجاح"

9. USER REDIRECTED
   │
   ├── Success: https://zuwad-academy.com/payment-has-been-successfully-completed/
   ├── Fail: https://zuwad-academy.com/payment-has-failed/
   └── Pending: https://zuwad-academy.com/payment-is-pending/
```

---

## Smart Balance Calculation

### Overview

The system uses a smart deposit algorithm that handles pending balances and applies currency-specific thresholds to determine whether to clear pending balances or keep residuals.

### Thresholds by Currency

| Currency | Threshold | Description |
|----------|-----------|-------------|
| EGP | 150 | Egyptian Pound |
| SAR | 20 | Saudi Riyal |
| OMR | 2 | Omani Rial |
| USD | 5 | US Dollar |
| AED | 20 | UAE Dirham |

### Calculation Logic

```php
// Step 1: Get current state
$current_balance = -50.00;     // Current wallet balance
$current_pending = -10.00;     // Current pending balance
$deposit_amount = 100.00;      // Amount being deposited
$threshold = 5;                // USD threshold

// Step 2: Combine deposit with pending
$effective_deposit = $deposit_amount + $current_pending;  // 100 + (-10) = 90

// Step 3: Calculate tentative balance
$tentative_balance = $current_balance + $effective_deposit;  // -50 + 90 = 40

// Step 4: Check if close to zero (within threshold)
if (abs($tentative_balance) < $threshold) {
    // Balance is close to zero - set to exactly 0
    $total_for_balance = -$current_balance;  // Add enough to reach 0 (50)
    $new_pending_balance = $tentative_balance;  // Put residual in pending (40)
    $pending_difference = $new_pending_balance - $current_pending;  // 40 - (-10) = 50
} else {
    // Balance is significantly non-zero
    $total_for_balance = $effective_deposit;  // Add full deposit (90)
    $new_pending_balance = 0;  // Clear pending
    $pending_difference = -$current_pending;  // Reset pending difference (10)
}

// Step 5: Final result
$new_balance = $current_balance + $total_for_balance;
```

### Example Scenarios

#### Scenario 1: Normal Deposit (No Pending)
```
Current Balance: -100 USD
Current Pending: 0 USD
Deposit: 150 USD
Threshold: 5 USD

Calculation:
effective_deposit = 150 + 0 = 150
tentative_balance = -100 + 150 = 50

Since 50 > 5 (not close to zero):
  new_balance = -100 + 150 = 50
  new_pending = 0

Result: Balance = 50 USD, Pending = 0 USD
```

#### Scenario 2: Deposit with Pending (Close to Zero)
```
Current Balance: -95 USD
Current Pending: -10 USD
Deposit: 100 USD
Threshold: 5 USD

Calculation:
effective_deposit = 100 + (-10) = 90
tentative_balance = -95 + 90 = -5

Since |-5| < 5 (close to zero):
  total_for_balance = 95 (to reach exactly 0)
  new_pending = -5
  pending_difference = -5 - (-10) = 5

Result: Balance = 0 USD, Pending = -5 USD
```

#### Scenario 3: Full Overpayment
```
Current Balance: -50 USD
Current Pending: -5 USD
Deposit: 100 USD
Threshold: 5 USD

Calculation:
effective_deposit = 100 + (-5) = 95
tentative_balance = -50 + 95 = 45

Since 45 > 5 (not close to zero):
  new_balance = -50 + 95 = 45
  new_pending = 0

Result: Balance = 45 USD, Pending = 0 USD
```

---

## Error Handling

### Common Error Codes

| Error | Description | Solution |
|-------|-------------|----------|
| `Missing required fields` | Invoice ID or status not provided | Check webhook payload |
| `Invoice not paid` | Status is not "paid" | Ignore webhook (only process paid) |
| `No payload data` | payLoad object missing | Ensure payLoad is sent with invoice |
| `Invalid payload` | Missing family_id or amount | Check payLoad structure |
| `Family not found` | family_id doesn't exist | Verify family exists |
| `Already processed` | Invoice was already processed | Normal behavior (idempotent) |
| `Failed to update balance` | Database error | Check database connection |

### Error Response Format

```json
{
    "status": "error",
    "message": "Human-readable error message"
}
```

---

## Flutter Code Examples

### 1. Create Invoice

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class FawaterkService {
  final String apiKey = 'a81aa852de53f0196680b87ccb2d43cd99080860a7be1fd548';
  final String apiUrl = 'https://app.fawaterk.com/api/v2/createInvoiceLink';

  Future<Map<String, dynamic>> createInvoice({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required double amount,
    required String currency,
    required int familyId,
  }) async {
    try {
      final requestBody = {
        'cartTotal': amount.toString(),
        'currency': currency,
        'customer': {
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'email': email,
        },
        'cartItems': [
          {
            'name': 'رسوم دراسية - زواد',
            'price': amount.toString(),
            'quantity': '1',
          }
        ],
        'redirectionUrls': {
          'successUrl': 'https://zuwad-academy.com/payment-has-been-successfully-completed/',
          'failUrl': 'https://zuwad-academy.com/payment-has-failed/',
          'pendingUrl': 'https://zuwad-academy.com/payment-is-pending/',
          'webhookUrl': 'https://system.zuwad-academy.com/wp-json/zuwad/v1/fawaterk-webhook_json',
        },
        'payLoad': {
          'family_id': familyId,
          'phone': phone,
          'currency': currency,
          'amount': amount,
        },
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {
            'success': true,
            'url': data['data']['url'],
            'invoiceId': data['data']['invoiceId'],
            'invoiceKey': data['data']['invoiceKey'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'فشل إنشاء الفاتورة',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'خطأ في الاتصال: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'استثناء: $e',
      };
    }
  }
}
```

### 2. Usage in Flutter Widget

```dart
import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentButton extends StatelessWidget {
  final int familyId;
  final String studentName;
  final String phone;
  final double amount;
  final String currency;

  const PaymentButton({
    Key? key,
    required this.familyId,
    required this.studentName,
    required this.phone,
    required this.amount,
    required this.currency,
  }) : super(key: key);

  Future<void> _createQuickInvoice(BuildContext context) async {
    // Split name into first and last
    final nameParts = studentName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : 'عميل';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'زواد';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إنشاء الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: $firstName $lastName'),
            Text('الهاتف: $phone'),
            Text('المبلغ: $amount $currency'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('إنشاء الفاتورة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Create invoice
    final service = FawaterkService();
    final result = await service.createInvoice(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: '',
      amount: amount,
      currency: currency,
      familyId: familyId,
    );

    // Close loading
    Navigator.pop(context);

    if (result['success'] == true) {
      final paymentUrl = result['url'] as String;

      // Show success dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ تم إنشاء رابط الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الاسم: $firstName $lastName'),
              Text('المبلغ: $amount $currency'),
              const SizedBox(height: 15),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: paymentUrl),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: paymentUrl));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم النسخ!')),
                );
              },
              child: const Text('📋 نسخ الرابط'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(paymentUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('🔗 فتح الرابط'),
            ),
          ],
        ),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'فشل إنشاء الفاتورة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show for non-EGP and non-OMR currencies
    if (currency == 'EGP' || currency == 'OMR') {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: () => _createQuickInvoice(context),
      icon: const Icon(Icons.payment, size: 18),
      label: const Text('💳'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
```

### 3. WebView Payment Handler (Optional)

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final int familyId;

  const PaymentWebView({
    Key? key,
    required this.paymentUrl,
    required this.familyId,
  }) : super(key: key);

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
          onNavigationRequest: (request) {
            // Check for redirect URLs
            if (request.url.contains('payment-has-been-successfully-completed')) {
              _handlePaymentSuccess();
              return NavigationDecision.prevent;
            }
            if (request.url.contains('payment-has-failed')) {
              _handlePaymentFailed();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handlePaymentSuccess() {
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم الدفع بنجاح!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handlePaymentFailed() {
    Navigator.pop(context, false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('فشلت عملية الدفع'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
```

---

## Supported Currencies

The following currencies are supported by Fawaterk:

| Code | Currency Name |
|------|---------------|
| USD | US Dollar |
| EGP | Egyptian Pound |
| SAR | Saudi Riyal |
| AED | UAE Dirham |
| KWD | Kuwaiti Dinar |
| QAR | Qatari Riyal |
| BHD | Bahraini Dinar |
| OMR | Omani Rial |
| JOD | Jordanian Dinar |
| EUR | Euro |
| GBP | British Pound |
| CAD | Canadian Dollar |
| TRY | Turkish Lira |
| DZD | Algerian Dinar |
| MAD | Moroccan Dirham |
| IQD | Iraqi Dinar |
| SDG | Sudanese Pound |
| SYP | Syrian Pound |
| BAM | Bosnia Mark |
| RON | Romanian Leu |
| MDL | Moldovan Leu |

---

## Testing Notes

### Quick Invoice Button Visibility
The quick invoice button (`💳`) is only shown for currencies **other than EGP and OMR**.

```javascript
// From family_wallet.js line 654
${!['EGP', 'OMR'].includes(currency) ? `<button class="btn btn-success quick-invoice-btn">...</button>` : ''}
```

### Webhook URL Requirement
The webhook URL MUST end with `_json` to receive JSON formatted data from Fawaterk.

```
✅ CORRECT: .../fawaterk-webhook_json
❌ INCORRECT: .../fawaterk-webhook
```

### Duplicate Prevention
The system checks if an invoice was already processed by looking for transactions with:
- `reference_id` = invoice_id
- `reference_type` = 'fawaterk_invoice'

---

## Important URLs

| Purpose | URL |
|---------|-----|
| Production API | https://app.fawaterk.com/api/v2/createInvoiceLink |
| Webhook Endpoint | https://system.zuwad-academy.com/wp-json/zuwad/v1/fawaterk-webhook_json |
| Success Redirect | https://zuwad-academy.com/payment-has-been-successfully-completed/ |
| Fail Redirect | https://zuwad-academy.com/payment-has-failed/ |
| Pending Redirect | https://zuwad-academy.com/payment-is-pending/ |

---

## Support

For issues or questions regarding the Fawaterk integration:
1. Check the [Fawaterk Documentation](https://fawaterk.com/en/docs)
2. Review the webhook logs in WordPress debug.log
3. Verify the payLoad data structure matches this guide

---

*Document Version: 1.0*
*Last Updated: 2025-01-31*
*For: Zuwad Academy Flutter App Development*
