import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../auth/domain/models/student.dart';
import '../../domain/models/wallet_info.dart';

/// Repository for settings and profile operations.
class SettingsRepository {
  final WordPressApi _api = WordPressApi();
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Get current user's student profile.
  Future<Student> getProfile() async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final data = await _api.getStudentProfile(userId);
    return Student.fromApiV2(data);
  }

  /// Update profile data fields.
  /// All provided fields will be sent to the API, even if empty.
  Future<Student> updateProfile({
    String? name,
    String? email,
    String? birthday,
    String? country,
    String? lessonsName,
    String? lessonDuration,
    int? lessonsNumber,
    int? amount,
  }) async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final Map<String, dynamic> updateData = {};

    // Add all provided fields - use isNotEmpty check to send actual values
    // Note: Backend uses 'display_name' for the student name field
    if (name != null && name.isNotEmpty) updateData['display_name'] = name;
    if (email != null) updateData['email'] = email;
    if (birthday != null) updateData['dob'] = birthday;
    if (country != null) updateData['country'] = country;
    if (lessonsName != null) updateData['lessons_name'] = lessonsName;
    if (lessonDuration != null) updateData['lesson_duration'] = lessonDuration;
    if (lessonsNumber != null) updateData['lessons_number'] = lessonsNumber;
    if (amount != null) updateData['amount'] = amount;

    if (kDebugMode) {
      print('SettingsRepository.updateProfile - userId: $userId');
      print('SettingsRepository.updateProfile - updateData: $updateData');
    }

    if (updateData.isEmpty) {
      throw Exception('No data to update');
    }

    final responseData = await _api.updateStudentProfile(userId, updateData);

    if (kDebugMode) {
      print('SettingsRepository.updateProfile - response: $responseData');
    }

    // Handle case where API returns {data: {...}} or just {...}
    final studentData = responseData['data'] ?? responseData;

    if (kDebugMode) {
      print('SettingsRepository.updateProfile - studentData: $studentData');
    }

    return Student.fromApiV2(studentData);
  }

  /// Change user's password.
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    return await _api.changePassword(currentPassword, newPassword);
  }

  /// Get wallet information for the student, including transactions.
  Future<WalletInfo> getWalletInfo() async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      // First get wallet info (balance, etc.)
      final walletData = await _api.getStudentWallet(userId);

      // Get family_id from wallet data (or use userId as fallback)
      final familyId = walletData['family_id'] ?? userId;

      if (kDebugMode) {
        print('SettingsRepository.getWalletInfo - familyId: $familyId');
      }

      // Fetch transactions separately from family endpoint
      final transactionsData = await _api.getWalletTransactions(familyId);

      if (kDebugMode) {
        print(
            'SettingsRepository.getWalletInfo - transactions count: ${transactionsData.length}');
      }

      // Combine wallet data with transactions
      final walletWithTransactions = Map<String, dynamic>.from(walletData);
      walletWithTransactions['transactions'] = transactionsData;

      return WalletInfo.fromJson(walletWithTransactions);
    } catch (e) {
      if (kDebugMode) {
        print('SettingsRepository.getWalletInfo - Error: $e');
      }
      // Return empty wallet if API fails
      return WalletInfo(
        balance: 0,
        pendingBalance: 0,
        currency: 'EGP',
        transactions: [],
      );
    }
  }
}
