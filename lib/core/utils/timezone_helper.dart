import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Helper class for timezone conversions.
/// All schedules are stored in Egypt time (Africa/Cairo) on the server.
/// This helper converts Egypt time to the student's country timezone.
class TimezoneHelper {
  static bool _isInitialized = false;
  static late tz.Location _egyptLocation;
  static tz.Location? _userLocation;

  /// Maps Arabic country names (as stored in the student profile) to IANA timezone names.
  static const Map<String, String> _countryToTimezone = {
    // Arab countries
    'مصر': 'Africa/Cairo',
    'عمان': 'Asia/Muscat',
    'الإمارات': 'Asia/Dubai',
    'المملكة العربية السعودية': 'Asia/Riyadh',
    'الكويت': 'Asia/Kuwait',
    'قطر': 'Asia/Qatar',
    'البحرين': 'Asia/Bahrain',
    'الأردن': 'Asia/Amman',
    'العراق': 'Asia/Baghdad',
    'سوريا': 'Asia/Damascus',
    'لبنان': 'Asia/Beirut',
    'اليمن': 'Asia/Aden',
    'فلسطين': 'Asia/Gaza',
    'ليبيا': 'Africa/Tripoli',
    'تونس': 'Africa/Tunis',
    'الجزائر': 'Africa/Algiers',
    'المغرب': 'Africa/Casablanca',
    'السودان': 'Africa/Khartoum',
    'الصومال': 'Africa/Mogadishu',
    'جيبوتي': 'Africa/Djibouti',
    'موريتانيا': 'Africa/Nouakchott',
    'قبرص': 'Asia/Nicosia',
    // Rest of the world (common countries for students)
    'تركيا': 'Europe/Istanbul',
    'إيران': 'Asia/Tehran',
    'أفغانستان': 'Asia/Kabul',
    'باكستان': 'Asia/Karachi',
    'الهند': 'Asia/Kolkata',
    'سريلانكا': 'Asia/Colombo',
    'بنغلاديش': 'Asia/Dhaka',
    'نيبال': 'Asia/Kathmandu',
    'ماليزيا': 'Asia/Kuala_Lumpur',
    'سنغافورة': 'Asia/Singapore',
    'إندونيسيا': 'Asia/Jakarta',
    'الفلبين': 'Asia/Manila',
    'الصين': 'Asia/Shanghai',
    'اليابان': 'Asia/Tokyo',
    'كوريا الجنوبية': 'Asia/Seoul',
    'كوريا الشمالية': 'Asia/Pyongyang',
    'تايوان': 'Asia/Taipei',
    'هونغ كونغ': 'Asia/Hong_Kong',
    'ماكاو': 'Asia/Macau',
    'تايلاند': 'Asia/Bangkok',
    'فيتنام': 'Asia/Ho_Chi_Minh',
    'كمبوديا': 'Asia/Phnom_Penh',
    'ميانمار': 'Asia/Rangoon',
    'لاوس': 'Asia/Vientiane',
    'أوزبكستان': 'Asia/Tashkent',
    'تركمانستان': 'Asia/Ashgabat',
    'كازاخستان': 'Asia/Almaty',
    'قرغيزستان': 'Asia/Bishkek',
    'أذربيجان': 'Asia/Baku',
    'أرمينيا': 'Asia/Yerevan',
    'جورجيا': 'Asia/Tbilisi',
    'روسيا': 'Europe/Moscow',
    'أوكرانيا': 'Europe/Kiev',
    'بيلاروسيا': 'Europe/Minsk',
    'بولندا': 'Europe/Warsaw',
    'ألمانيا': 'Europe/Berlin',
    'فرنسا': 'Europe/Paris',
    'إسبانيا': 'Europe/Madrid',
    'إيطاليا': 'Europe/Rome',
    'المملكة المتحدة': 'Europe/London',
    'هولندا': 'Europe/Amsterdam',
    'بلجيكا': 'Europe/Brussels',
    'سويسرا': 'Europe/Zurich',
    'النمسا': 'Europe/Vienna',
    'السويد': 'Europe/Stockholm',
    'النرويج': 'Europe/Oslo',
    'الدنمارك': 'Europe/Copenhagen',
    'فنلندا': 'Europe/Helsinki',
    'اليونان': 'Europe/Athens',
    'رومانيا': 'Europe/Bucharest',
    'بلغاريا': 'Europe/Sofia',
    'صربيا': 'Europe/Belgrade',
    'كرواتيا': 'Europe/Zagreb',
    'جمهورية التشيك': 'Europe/Prague',
    'سلوفاكيا': 'Europe/Bratislava',
    'المجر': 'Europe/Budapest',
    'لاتفيا': 'Europe/Riga',
    'ليتوانيا': 'Europe/Vilnius',
    'إستونيا': 'Europe/Tallinn',
    'البرتغال': 'Europe/Lisbon',
    'أيرلندا': 'Europe/Dublin',
    'أيسلندا': 'Atlantic/Reykjavik',
    'مالطا': 'Europe/Malta',
    'أستراليا': 'Australia/Sydney',
    'نيوزيلندا': 'Pacific/Auckland',
    'كندا': 'America/Toronto',
    'الولايات المتحدة': 'America/New_York',
    'المكسيك': 'America/Mexico_City',
    'البرازيل': 'America/Sao_Paulo',
    'الأرجنتين': 'America/Argentina/Buenos_Aires',
    'كولومبيا': 'America/Bogota',
    'بيرو': 'America/Lima',
    'تشيلي': 'America/Santiago',
    'فنزويلا': 'America/Caracas',
    'الإكوادور': 'America/Guayaquil',
    'بوليفيا': 'America/La_Paz',
    'باراغواي': 'America/Asuncion',
    'أوروغواي': 'America/Montevideo',
    'كوبا': 'America/Havana',
    'جامايكا': 'America/Jamaica',
    'جنوب أفريقيا': 'Africa/Johannesburg',
    'كينيا': 'Africa/Nairobi',
    'إثيوبيا': 'Africa/Addis_Ababa',
    'تنزانيا': 'Africa/Dar_es_Salaam',
    'أوغندا': 'Africa/Kampala',
    'رواندا': 'Africa/Kigali',
    'نيجيريا': 'Africa/Lagos',
    'غانا': 'Africa/Accra',
    'الكاميرون': 'Africa/Douala',
    'السنغال': 'Africa/Dakar',
    'الغابون': 'Africa/Libreville',
    'جنوب السودان': 'Africa/Juba',
    'الصحراء الغربية': 'Africa/El_Aaiun',
    'موزمبيق': 'Africa/Maputo',
    'زيمبابوي': 'Africa/Harare',
    'زامبيا': 'Africa/Lusaka',
    'مدغشقر': 'Indian/Antananarivo',
    'موريشيوس': 'Indian/Mauritius',
    'جزر المالديف': 'Indian/Maldives',
    'سيشل': 'Indian/Mahe',
    'جزر القمر': 'Indian/Comoro',
  };

  /// Initialize timezone data. Call this once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _isInitialized = true;

      if (kDebugMode) {
        print('TimezoneHelper initialized (Egypt timezone: ${_egyptLocation.name})');
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing timezone: $e');
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _isInitialized = true;
    }
  }

  /// Set the user's timezone based on the student's country (Arabic name from profile).
  /// Call this after loading the student profile.
  static void setUserCountry(String? arabicCountry) {
    if (arabicCountry == null || arabicCountry.isEmpty) {
      _userLocation = null;
      if (kDebugMode) print('TimezoneHelper: no country set, will use device timezone');
      return;
    }

    final tzName = _countryToTimezone[arabicCountry];
    if (tzName == null) {
      _userLocation = null;
      if (kDebugMode) print('TimezoneHelper: unknown country "$arabicCountry", will use device timezone');
      return;
    }

    try {
      _userLocation = tz.getLocation(tzName);
      if (kDebugMode) print('TimezoneHelper: country="$arabicCountry" → timezone=$tzName');
    } catch (e) {
      _userLocation = null;
      if (kDebugMode) print('TimezoneHelper: failed to load timezone $tzName: $e');
    }
  }

  /// Convert a DateTime from Egypt time to the student's local time.
  static DateTime egyptToLocal(DateTime egyptDateTime) {
    if (!_isInitialized) return egyptDateTime;

    try {
      final egyptTZ = tz.TZDateTime(
        _egyptLocation,
        egyptDateTime.year,
        egyptDateTime.month,
        egyptDateTime.day,
        egyptDateTime.hour,
        egyptDateTime.minute,
        egyptDateTime.second,
      );

      if (_userLocation != null) {
        // Convert using timezone package — pure Dart, works on web and native.
        final userTZ = tz.TZDateTime.from(egyptTZ, _userLocation!);
        if (kDebugMode) {
          print('egyptToLocal: $egyptDateTime (Egypt) → $userTZ (${_userLocation!.name})');
        }
        return DateTime(userTZ.year, userTZ.month, userTZ.day,
            userTZ.hour, userTZ.minute, userTZ.second);
      }

      // Fallback: use device timezone offset (for native where it's reliable)
      final deviceOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      final egyptOffsetMinutes = egyptTZ.timeZoneOffset.inMinutes;
      final diff = deviceOffsetMinutes - egyptOffsetMinutes;
      return DateTime(egyptDateTime.year, egyptDateTime.month, egyptDateTime.day,
              egyptDateTime.hour, egyptDateTime.minute, egyptDateTime.second)
          .add(Duration(minutes: diff));
    } catch (e) {
      if (kDebugMode) print('Error in egyptToLocal: $e');
      return egyptDateTime;
    }
  }

  /// Async version — same logic, kept for API compatibility.
  static Future<DateTime> egyptToLocalAsync(DateTime egyptDateTime) async {
    return egyptToLocal(egyptDateTime);
  }

  /// Convert an Egypt time to UTC. Use this for countdown calculations so
  /// that comparing with DateTime.now().toUtc() works correctly on all platforms.
  static DateTime egyptToUtc(DateTime egyptDateTime) {
    if (!_isInitialized) return egyptDateTime;
    try {
      final egyptTZ = tz.TZDateTime(
        _egyptLocation,
        egyptDateTime.year,
        egyptDateTime.month,
        egyptDateTime.day,
        egyptDateTime.hour,
        egyptDateTime.minute,
        egyptDateTime.second,
      );
      return DateTime.fromMillisecondsSinceEpoch(
        egyptTZ.millisecondsSinceEpoch,
        isUtc: true,
      );
    } catch (e) {
      if (kDebugMode) print('Error in egyptToUtc: $e');
      return egyptDateTime;
    }
  }

  /// Convert a DateTime from local (student's country) time to Egypt time.
  static DateTime localToEgypt(DateTime localDateTime) {
    if (!_isInitialized) return localDateTime;

    try {
      if (_userLocation != null) {
        final localTZ = tz.TZDateTime(
          _userLocation!,
          localDateTime.year,
          localDateTime.month,
          localDateTime.day,
          localDateTime.hour,
          localDateTime.minute,
          localDateTime.second,
        );
        final egyptTZ = tz.TZDateTime.from(localTZ, _egyptLocation);
        return DateTime(egyptTZ.year, egyptTZ.month, egyptTZ.day,
            egyptTZ.hour, egyptTZ.minute, egyptTZ.second);
      }

      // Fallback
      final egyptTZ = tz.TZDateTime.from(localDateTime, _egyptLocation);
      return DateTime(egyptTZ.year, egyptTZ.month, egyptTZ.day,
          egyptTZ.hour, egyptTZ.minute, egyptTZ.second);
    } catch (e) {
      if (kDebugMode) print('Error in localToEgypt: $e');
      return localDateTime;
    }
  }

  /// Async version — same logic, kept for API compatibility.
  static Future<DateTime> localToEgyptAsync(DateTime localDateTime) async {
    return localToEgypt(localDateTime);
  }

  /// Get the current time in Egypt timezone.
  static DateTime nowInEgypt() => localToEgypt(DateTime.now());

  static bool get isInitialized => _isInitialized;
  static String? get userTimezone => _userLocation?.name;
  static int get deviceTimezoneOffsetHours => DateTime.now().timeZoneOffset.inHours;
  static int get egyptTimezoneOffsetHours {
    if (!_isInitialized) return 2;
    return tz.TZDateTime.now(_egyptLocation).timeZoneOffset.inHours;
  }
}
