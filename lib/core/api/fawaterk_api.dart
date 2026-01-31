import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Fawaterk Payment Gateway API service.
///
/// This class handles communication with the Fawaterk payment gateway API
/// for creating invoice links for payment processing.
///
/// API Documentation: https://fawaterak-api.readme.io/reference/sendpayment
class FawaterkApi {
  static const String _baseUrl = 'https://app.fawaterk.com/api/v2';
  static const String _apiKey = 'a81aa852de53f0196680b87ccb2d43cd99080860a7be1fd548';

  final Dio _dio = Dio();

  FawaterkApi() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  /// Create a payment invoice link via Fawaterk API.
  ///
  /// Returns a Map with:
  /// - `success`: bool indicating if the request was successful
  /// - `url`: String with the payment URL (if successful)
  /// - `message`: String with error message (if failed)
  Future<Map<String, dynamic>> createInvoiceLink({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required double amount,
    required String currency,
    required int familyId,
  }) async {
    try {
      if (kDebugMode) {
        print('FawaterkApi: Creating invoice for family $familyId');
        print('FawaterkApi: Amount: $amount $currency');
      }

      final response = await _dio.post(
        '$_baseUrl/createInvoiceLink',
        data: {
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
              'quantity': 1,
            }
          ],
          'redirectionUrls': {
            'successUrl': 'https://zuwad.com/payment/success',
            'failUrl': 'https://zuwad.com/payment/fail',
            'pendingUrl': 'https://zuwad.com/payment/pending',
          },
          'payLoad': {
            'family_id': familyId,
            'phone': phone,
            'currency': currency,
            'amount': amount.toString(),
          },
        },
      );

      if (kDebugMode) {
        print('FawaterkApi: Response status: ${response.statusCode}');
        print('FawaterkApi: Response data: ${response.data}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        // Check if response contains URL or data with URL
        if (jsonData is Map<String, dynamic>) {
          if (jsonData['success'] == true || jsonData['status'] == 'success') {
            final url = jsonData['data']?['url'] ?? jsonData['url'];
            if (url != null && url.toString().isNotEmpty) {
              return {
                'success': true,
                'url': url.toString(),
              };
            }
          }
          // Check for error message
          final errorMsg = jsonData['error']?['message'] ??
              jsonData['message'] ??
              jsonData['msg'];
          if (errorMsg != null) {
            return {
              'success': false,
              'message': errorMsg.toString(),
            };
          }
        }
      }

      return {
        'success': false,
        'message': 'فشل إنشاء رابط الدفع',
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('FawaterkApi: DioException - ${e.message}');
        print('FawaterkApi: Response - ${e.response?.data}');
      }
      final errorMessage = e.response?.data?['message']?.toString() ??
          e.response?.data?['error']?.toString() ??
          e.message ??
          'فشل الاتصال ببوابة الدفع';
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      if (kDebugMode) {
        print('FawaterkApi: Error - $e');
      }
      return {
        'success': false,
        'message': 'فشل إنشاء رابط الدفع: ${e.toString()}',
      };
    }
  }
}
