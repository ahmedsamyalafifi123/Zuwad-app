# Zuwad App - Comprehensive Code Analysis Report

**Date:** December 23, 2025  
**App Version:** 1.0.1+13  
**Framework:** Flutter/Dart

---

## Table of Contents

1. [Critical Security Issues](#critical-security-issues)
2. [Architectural Issues](#architectural-issues)
3. [Code Quality Issues](#code-quality-issues)
4. [Performance Concerns](#performance-concerns)
5. [Bug Risks](#bug-risks)
6. [Best Practice Violations](#best-practice-violations)
7. [Recommendations Summary](#recommendations-summary)

---

## Critical Security Issues

> [!CAUTION]
> These issues pose significant security risks and should be addressed immediately.

### 1. **Exposed API Keys & Secrets in Source Code**

**File:** `lib/core/config/livekit_config.dart`

```dart
static const String apiKey = 'APIjTeJvsRwm8Fb';
static const String apiSecret = '1QiaedSSZBeQukQPB1FB6dYeg2EePzsq1lWlmIrw9tNA';
```

**Risk:** API keys and secrets are hardcoded and will be exposed in the compiled app binary. Attackers can extract these credentials.

**Solution:**

- Use environment variables or a secrets management solution
- Fetch tokens from your backend server instead of generating them client-side
- Use `flutter_dotenv` or `envied` package for environment configuration

---

### 2. **JWT Token Generated Client-Side with Secret**

**File:** `lib/services/livekit_service.dart` (Lines 18-55)

The app generates JWT tokens on the client side using the API secret:

```dart
String generateToken({...}) {
  final key = utf8.encode(LiveKitConfig.apiSecret);
  final hmac = Hmac(sha256, key);
  // ...
}
```

**Risk:** The API secret is bundled in the app, allowing anyone to generate valid tokens.

**Solution:** Move token generation to your backend server and have the app request tokens via authenticated API calls.

---

### 3. **Auth Token Stored in SharedPreferences (Not Secure)**

**File:** `lib/core/api/wordpress_api.dart` (Lines 50-54)

```dart
await prefs.setString('auth_token', response.data['token']);
```

**Risk:** `SharedPreferences` is not encrypted and can be accessed by other apps on rooted devices.

**Solution:** You already have a `SecureStorageService` class - use it consistently throughout the app instead of `SharedPreferences` for sensitive data.

---

## Architectural Issues

### 4. **Duplicate/Inconsistent URL Configuration**

Three different places define base URLs:

| File                                | URL                                                         |
| ----------------------------------- | ----------------------------------------------------------- |
| `core/api/wordpress_api.dart`       | `https://system.zuwad-academy.com/wp-json`                  |
| `core/constants/api_constants.dart` | `https://system.zuwad-academy.com`                          |
| `core/utils/constants.dart`         | `https://your-wordpress-site.com/wp-json` ❌ (placeholder!) |

**Solution:** Consolidate all configuration into a single source of truth (`api_constants.dart`) and remove placeholder values.

---

### 5. **SecureStorageService Created But Not Used**

**File:** `lib/core/services/secure_storage_service.dart`

This service exists but is never used in the codebase. Instead, the app uses raw `SharedPreferences`:

- `auth_repository.dart` uses `SharedPreferences`
- `wordpress_api.dart` uses `SharedPreferences`
- `chat_repository.dart` uses `SharedPreferences`

**Solution:** Replace all `SharedPreferences` usage for sensitive data with `SecureStorageService`.

---

### 6. **Missing Dependency Injection**

Multiple classes instantiate their own dependencies:

```dart
// wordpress_api.dart
final Dio _dio = Dio();

// auth_repository.dart
final WordPressApi _api = WordPressApi();

// schedule_repository.dart
// Creates its own instances
```

**Issues:**

- Hard to test (no mocking)
- No control over lifecycle
- Memory inefficiency

**Solution:** Use `get_it` or `riverpod` for dependency injection.

---

### 7. **Mixed HTTP Clients**

The app uses both `dio` and `http` packages:

- `wordpress_api.dart` uses `Dio`
- `chat_repository.dart` uses `http`

**Solution:** Standardize on one HTTP client (recommend `Dio` for its interceptor support).

---

## Code Quality Issues

### 8. **Extensive Debug Print Statements in Production Code**

> [!WARNING]
> Over 80+ print statements found across the codebase. These slow down the app and expose internal details in logs.

**Files with excessive prints:**
| File | Approximate Count |
|------|-------------------|
| `wordpress_api.dart` | 3 |
| `chat_message.dart` | 1 |
| `chat_repository.dart` | 12+ |
| `chat_page.dart` | 15+ |
| `meeting_page.dart` | 25+ |
| `livekit_service.dart` | 20+ |
| `student_dashboard_page.dart` | 30+ |

**Solution:**

- Use `kDebugMode` guard for all prints (good example in `auth_bloc.dart`)
- Or use a logging package like `logger`

---

### 9. **Unused Private Variables**

**File:** `lib/features/chat/presentation/pages/chat_page.dart`

```dart
final List<types.Message> _messages = [];  // Line 33 - never used
String? _lastMessageId;  // Line 39 - assigned but never read
```

---

### 10. **Dead Code and Empty Methods**

**File:** `lib/features/chat/data/repositories/chat_repository.dart`

```dart
// This method is no longer needed as we're not using local database for messages
Future<void> retrySendingPendingMessages() async {
  // No-op as we're not using local database for messages anymore
  return;
}
```

**Solution:** Remove dead code instead of leaving empty methods with comments.

---

### 11. **Private Widget Missing `const` Constructor**

**File:** `lib/features/student_dashboard/presentation/pages/student_dashboard_page.dart`

```dart
class _DashboardContent extends StatefulWidget {
  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}
```

**Solution:** Add `const` constructor: `const _DashboardContent({super.key});`

---

## Performance Concerns

### 12. **Chat Polling Every 5 Seconds**

**File:** `lib/features/chat/presentation/pages/chat_page.dart` (Line 174)

```dart
_refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  if (mounted) {
    _refreshMessages();
  }
});
```

**Issues:**

- Battery drain
- Unnecessary network usage
- Not scalable

**Solution:** Implement WebSocket or Server-Sent Events (SSE) for real-time updates, or use Firebase Cloud Messaging for push notifications.

---

### 13. **No Image Caching Strategy**

While `cached_network_image` is in dependencies, there's no evidence of using it for network images.

---

### 14. **Timer Not Cancelled Properly**

**File:** `lib/features/student_dashboard/presentation/pages/student_dashboard_page.dart`

The countdown timer is cancelled in `dispose`, but if `_loadNextLesson` is called while a timer is already running, it creates multiple timers before cancelling the old one.

---

## Bug Risks

### 15. **Connectivity Check Returns Wrong Type**

**File:** `lib/features/chat/data/repositories/chat_repository.dart` (Line 18)

```dart
_connectivity.onConnectivityChanged.listen((result) async {
  if (result != ConnectivityResult.none) {
```

**Issue:** In newer versions of `connectivity_plus`, `onConnectivityChanged` returns `List<ConnectivityResult>`, not a single value.

**Solution:** Update to handle the list:

```dart
.listen((results) async {
  if (!results.contains(ConnectivityResult.none)) {
```

---

### 16. **Timestamp Parsing Assumes UTC**

**File:** `lib/features/chat/data/models/chat_message.dart` (Line 43)

```dart
DateTime.parse('${timestampStr}Z').toLocal();
```

**Issue:** This assumes all timestamps from the server are UTC, but doesn't validate the format. If the server sends local time or includes timezone info, this will break.

---

### 17. **Missing Null Safety for UI Elements**

**File:** `lib/features/chat/presentation/pages/chat_page.dart` (Line 364)

```dart
widget.recipientName[0].toUpperCase()
```

**Issue:** No check if `recipientName` is empty before accessing `[0]`.

---

### 18. **Color.withOpacity Deprecated in Latest Flutter**

Multiple files use `color.withOpacity()` which is deprecated:

```dart
color: AppTheme.primaryColor.withOpacity(0.3)
```

**Solution:** Use `color.withValues(alpha: 0.3)` in Flutter 3.27+

---

## Best Practice Violations

### 19. **No Error Boundary/Global Error Handling**

The app doesn't have:

- `FlutterError.onError` handler
- `PlatformDispatcher.instance.onError` for async errors
- Crash reporting (Crashlytics, Sentry)

---

### 20. **Hardcoded Strings (No Localization)**

UI strings are hardcoded in Arabic throughout the app. While the app targets Arabic users, this makes:

- Future localization difficult
- Text maintenance scattered

**Example:** `lib/features/auth/presentation/pages/login_page.dart`

```dart
const Text('أكاديمية زواد', ...)
const Text('تسجيل دخول الطالب', ...)
```

**Solution:** Use `flutter_localizations` with ARB files (already in dependencies but not implemented).

---

### 21. **No Input Sanitization**

User inputs are not sanitized before sending to API:

```dart
body: jsonEncode({
  'phone': phone,
  'password': password,
}),
```

---

### 22. **Missing Loading/Error States**

Some BLoC states don't handle all edge cases. For example, in chat:

- No "no internet" state
- No retry mechanism for failed operations

---

### 23. **Inconsistent Error Messages**

Error messages mix Arabic and English:

```dart
throw Exception('Not authenticated');  // English
emit(AuthError('فشل تسجيل الدخول'));    // Arabic
```

---

### 24. **Student Model Missing `toJson` Method**

**File:** `lib/features/auth/domain/models/student.dart`

Has `fromJson` but no `toJson` - needed for local caching/persistence.

---

### 25. **Using deprecated `withOpacity`**

Multiple locations use the deprecated pattern. Should migrate to the new API.

---

## Recommendations Summary

### Immediate Actions (Security)

1. ⚠️ Remove API keys from source code - use backend token generation
2. ⚠️ Replace `SharedPreferences` with `SecureStorageService` for tokens
3. ⚠️ Add certificate pinning for API calls

### High Priority

4. Remove or guard all print statements with `kDebugMode`
5. Consolidate URL configuration into single source
6. Add global error handling and crash reporting
7. Fix connectivity check for newer `connectivity_plus`

### Medium Priority

8. Implement dependency injection
9. Standardize HTTP client (use Dio only)
10. Replace polling with WebSocket/Push notifications
11. Add proper input validation
12. Remove dead code and unused variables

### Low Priority

13. Add `toJson` to models
14. Implement proper localization
15. Add unit tests for repositories
16. Document public APIs

---

## Files Analyzed

| Category  | Files                                                                                                                                                   |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Core      | `wordpress_api.dart`, `api_constants.dart`, `constants.dart`, `secure_storage_service.dart`, `app_theme.dart`, `exceptions.dart`, `livekit_config.dart` |
| Auth      | `auth_bloc.dart`, `auth_repository.dart`, `student.dart`, `login_page.dart`, `splash_screen.dart`                                                       |
| Chat      | `chat_message.dart`, `chat_repository.dart`, `chat_page.dart`, `chat_list_page.dart`                                                                    |
| Meeting   | `meeting_page.dart`, `livekit_service.dart`                                                                                                             |
| Dashboard | `student_dashboard_page.dart`, `home_page.dart`                                                                                                         |

---

_This report was generated by analyzing the Zuwad Flutter application source code._
