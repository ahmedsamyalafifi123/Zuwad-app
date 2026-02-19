import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/settings_cache_service.dart';
import '../../../auth/domain/models/student.dart';
import '../../domain/models/wallet_info.dart';

/// Repository for settings and profile operations.
class SettingsRepository {
  final WordPressApi _api = WordPressApi();
  final SecureStorageService _secureStorage = SecureStorageService();
  final SettingsCacheService _cache = SettingsCacheService.instance;

  /// Check if cached data is available
  bool get hasCachedData => _cache.hasCachedData;

  /// Get cached student if available
  Student? get cachedStudent => _cache.cachedStudent;

  /// Get cached wallet info if available
  WalletInfo? get cachedWalletInfo => _cache.cachedWalletInfo;

  /// Get cached family members if available
  List<Map<String, dynamic>>? get cachedFamilyMembers =>
      _cache.cachedFamilyMembers;

  /// Clear all cached data
  void clearCache() => _cache.clearCache();

  /// Get current user's student profile.
  Future<Student> getProfile({bool forceRefresh = false}) async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final data = await _api.getStudentProfile(userId);
    final student = Student.fromApiV2(data);

    // Fetch teacher details if available (same logic as AuthRepository)
    if (student.teacherId != null && student.teacherId! > 0) {
      try {
        final teacherData = await _api.getTeacherData(student.teacherId!);
        if (teacherData.isNotEmpty) {
          final teacherGender = teacherData['gender']?.toString();
          // Try multiple keys for image
          final teacherImage = teacherData['profile_image']?.toString() ??
              teacherData['profile_image_url']?.toString() ??
              teacherData['avatar']?.toString() ??
              teacherData['avatar_url']?.toString() ??
              teacherData['user_avatar']?.toString();

          // Create updated student with teacher details
          final updatedStudent = student.copyWith(
            teacherGender: teacherGender,
            teacherImage: teacherImage,
          );

          // Update cache with detailed student info
          _cache.setStudent(updatedStudent);
          return updatedStudent;
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              'SettingsRepository.getProfile: Failed to get teacher details: $e');
        }
      }
    }

    // Update cache if no teacher details found or fetch failed
    _cache.setStudent(student);

    return student;
  }

  /// Upload profile image.
  Future<String> uploadProfileImage(File imageFile) async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }
    return await _api.uploadStudentProfileImage(userId, imageFile.path);
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
      if (kDebugMode) {
        print('DEBUG: Wallet Data: $walletData');
      }

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

      final walletInfo = WalletInfo.fromJson(walletWithTransactions);

      // Update cache
      _cache.setWalletInfo(walletInfo);

      return walletInfo;
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

  /// Get family members for the student.
  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    final userId = await _secureStorage.getUserIdAsInt();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      final members = await _api.getStudentFamily(userId);
      // Create a modifiable list
      final List<Map<String, dynamic>> modifiableMembers =
          List<Map<String, dynamic>>.from(members);

      // Attempt to populate amount for ALL family members
      // We fetch the profile for each member to get the correct amount
      // Family size is typically small, so this N+1 is acceptable for data accuracy
      try {
        final futures = modifiableMembers.map((member) async {
          try {
            final memberId = member['id'];
            final profile = await _api.getStudentProfile(memberId);
            final updatedMember = Map<String, dynamic>.from(member);
            updatedMember['amount'] = profile['amount'];
            updatedMember['remaining_lessons'] = profile['remaining_lessons'];
            if (profile['currency'] != null) {
              updatedMember['currency'] = profile['currency'];
            }
            return updatedMember;
          } catch (e) {
            if (kDebugMode) {
              print(
                  'SettingsRepository.getFamilyMembers - Error fetching profile for member ${member['id']}: $e');
            }
            return member; // Return original if fetch fails
          }
        });

        final results = await Future.wait(futures);
        modifiableMembers
          ..clear()
          ..addAll(results);
      } catch (e) {
        if (kDebugMode) {
          print(
              'SettingsRepository.getFamilyMembers - Error in profile fetch loop: $e');
        }
      }

      // Update cache
      _cache.setFamilyMembers(modifiableMembers);

      return modifiableMembers;
    } catch (e) {
      if (kDebugMode) {
        print('SettingsRepository.getFamilyMembers - Error: $e');
      }
      return [];
    }
  }
}
