import '../../../features/auth/domain/models/student.dart';
import '../../../features/student_dashboard/domain/models/wallet_info.dart';

/// In-memory cache service for settings page data.
///
/// This cache:
/// - Persists during navigation (in-memory)
/// - Is cleared on pull-to-refresh (manual clear)
/// - Is automatically cleared when app closes (in-memory only)
class SettingsCacheService {
  // Singleton pattern
  SettingsCacheService._();
  static final instance = SettingsCacheService._();

  // Cached data (private)
  Student? _cachedStudent;
  WalletInfo? _cachedWalletInfo;
  List<Map<String, dynamic>>? _cachedFamilyMembers;

  // Public getters
  Student? get cachedStudent => _cachedStudent;
  WalletInfo? get cachedWalletInfo => _cachedWalletInfo;
  List<Map<String, dynamic>>? get cachedFamilyMembers => _cachedFamilyMembers;

  bool get hasCachedData =>
      _cachedStudent != null &&
      _cachedWalletInfo != null &&
      _cachedFamilyMembers != null;

  /// Set individual cached items (for repository use)
  void setStudent(Student student) => _cachedStudent = student;
  void setWalletInfo(WalletInfo walletInfo) => _cachedWalletInfo = walletInfo;
  void setFamilyMembers(List<Map<String, dynamic>> familyMembers) =>
      _cachedFamilyMembers = familyMembers;

  /// Cache all settings data at once
  void cacheData({
    required Student student,
    required WalletInfo walletInfo,
    required List<Map<String, dynamic>> familyMembers,
  }) {
    _cachedStudent = student;
    _cachedWalletInfo = walletInfo;
    _cachedFamilyMembers = familyMembers;
  }

  /// Clear all cached data (called on refresh)
  void clearCache() {
    _cachedStudent = null;
    _cachedWalletInfo = null;
    _cachedFamilyMembers = null;
  }
}
