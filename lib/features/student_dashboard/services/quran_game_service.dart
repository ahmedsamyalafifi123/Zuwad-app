import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class QuranGameService {
  Map<String, dynamic>? _gamesData;

  // Map of surah names to numbers (114 surahs)
  static const Map<String, int> surahNameToNumber = {
    'الفاتحة': 1,
    'البقرة': 2,
    'آل عمران': 3,
    'النساء': 4,
    'المائدة': 5,
    'الأنعام': 6,
    'الأعراف': 7,
    'الأنفال': 8,
    'التوبة': 9,
    'يونس': 10,
    'هود': 11,
    'يوسف': 12,
    'الرعد': 13,
    'إبراهيم': 14,
    'الحجر': 15,
    'النحل': 16,
    'الإسراء': 17,
    'الكهف': 18,
    'مريم': 19,
    'طه': 20,
    'الأنبياء': 21,
    'الحج': 22,
    'المؤمنون': 23,
    'النور': 24,
    'الفرقان': 25,
    'الشعراء': 26,
    'النمل': 27,
    'القصص': 28,
    'العنكبوت': 29,
    'الروم': 30,
    'لقمان': 31,
    'السجدة': 32,
    'الأحزاب': 33,
    'سبأ': 34,
    'فاطر': 35,
    'يس': 36,
    'الصافات': 37,
    'ص': 38,
    'الزمر': 39,
    'غافر': 40,
    'فصلت': 41,
    'الشورى': 42,
    'الزخرف': 43,
    'الدخان': 44,
    'الجاثية': 45,
    'الأحقاف': 46,
    'محمد': 47,
    'الفتح': 48,
    'الحجرات': 49,
    'ق': 50,
    'الذاريات': 51,
    'الطور': 52,
    'النجم': 53,
    'القمر': 54,
    'الرحمن': 55,
    'الواقعة': 56,
    'الحديد': 57,
    'المجادلة': 58,
    'الحشر': 59,
    'الممتحنة': 60,
    'الصف': 61,
    'الجمعة': 62,
    'المنافقون': 63,
    'التغابن': 64,
    'الطلاق': 65,
    'التحريم': 66,
    'الملك': 67,
    'القلم': 68,
    'الحاقة': 69,
    'المعارج': 70,
    'نوح': 71,
    'الجن': 72,
    'المزمل': 73,
    'المدثر': 74,
    'القيامة': 75,
    'الإنسان': 76,
    'المرسلات': 77,
    'النبأ': 78,
    'النازعات': 79,
    'عبس': 80,
    'التكوير': 81,
    'الانفطار': 82,
    'المطففين': 83,
    'الانشقاق': 84,
    'البروج': 85,
    'الطارق': 86,
    'الأعلى': 87,
    'الغاشية': 88,
    'الفجر': 89,
    'البلد': 90,
    'الشمس': 91,
    'الليل': 92,
    'الضحى': 93,
    'الشرح': 94,
    'التين': 95,
    'العلق': 96,
    'القدر': 97,
    'البينة': 98,
    'الزلزلة': 99,
    'العاديات': 100,
    'القارعة': 101,
    'التكاثر': 102,
    'العصر': 103,
    'الهمزة': 104,
    'الفيل': 105,
    'قريش': 106,
    'الماعون': 107,
    'الكوثر': 108,
    'الكافرون': 109,
    'النصر': 110,
    'المسد': 111,
    'الإخلاص': 112,
    'الفلق': 113,
    'الناس': 114,
  };

  /// Load games data from assets
  Future<void> loadGamesData() async {
    if (_gamesData != null) return; // Already loaded

    try {
      final jsonString = await rootBundle.loadString('assets/quran_games.json');
      _gamesData = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading quran_games.json: $e');
      _gamesData = {};
    }
  }

  /// Normalize Arabic text to handle character variations
  String _normalizeArabic(String text) {
    return text
        // Normalize alif variations
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        // Normalize ya variations
        .replaceAll('ي', 'ى')
        // Normalize ta marbuta and ha
        .replaceAll('ة', 'ه')
        // Remove tashkeel (diacritics)
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        // Trim whitespace
        .trim();
  }

  /// Extract surah number from nextTasmii string
  /// Examples: "الضحى1-3", "الضحى3", "الضحى" → 93
  int? extractSurahNumber(String nextTasmii) {
    if (nextTasmii.isEmpty) return null;

    // Remove numbers and ranges from the end
    // Regex matches: digits, hyphens, and Arabic-Indic digits
    final surahName = nextTasmii.replaceAll(RegExp(r'[\d\-٠-٩]+$'), '').trim();

    if (surahName.isEmpty) return null;

    // Normalize the extracted name
    final normalizedName = _normalizeArabic(surahName);

    // Try to find a match by normalizing all surah names
    for (var entry in surahNameToNumber.entries) {
      final normalizedSurahKey = _normalizeArabic(entry.key);
      if (normalizedSurahKey == normalizedName) {
        return entry.value;
      }
    }

    return null; // No match found
  }

  /// Get a random game from surahs after the given surah number
  /// If no games found or surahNumber is null, fallback to surahs 110-114
  /// [excludeGameIds] - List of game IDs to exclude from selection
  Future<Map<String, dynamic>?> getRandomGame(
    int? surahNumber, {
    List<String> excludeGameIds = const [],
  }) async {
    await loadGamesData();

    if (_gamesData == null || _gamesData!.isEmpty) {
      return null;
    }

    List<Map<String, dynamic>> availableGames = [];

    // Determine the range of surahs to search
    int startSurah;
    int endSurah = 114;

    if (surahNumber != null && surahNumber < 114) {
      // Normal case: get games from next surah to end
      startSurah = surahNumber + 1;
    } else {
      // Fallback: use last 5 surahs (110-114)
      startSurah = 110;
    }

    // Collect all games from the target range
    for (var entry in _gamesData!.entries) {
      final surahData = entry.value as Map<String, dynamic>;
      final surahNum = surahData['surah_number'] as int?;

      if (surahNum != null && surahNum >= startSurah && surahNum <= endSurah) {
        final games = surahData['games'] as List<dynamic>?;
        if (games != null && games.isNotEmpty) {
          for (var game in games) {
            if (game is Map<String, dynamic>) {
              final gameId = game['game_id'] as String?;
              // Exclude games that are in the excludeGameIds list
              if (gameId == null || !excludeGameIds.contains(gameId)) {
                availableGames.add(game);
              }
            }
          }
        }
      }
    }

    // If no games found even in fallback range, return null
    if (availableGames.isEmpty) {
      return null;
    }

    // Return a random game
    final random = Random();
    return availableGames[random.nextInt(availableGames.length)];
  }

  /// Get the embed URL from a game
  String? getGameUrl(Map<String, dynamic> game) {
    // First try to construct from game_id
    final gameId = game['game_id'] as String?;
    final themeId = game['theme_id']?.toString() ?? '0';
    final templateId = game['template_id']?.toString() ?? '3';

    if (gameId != null && gameId.isNotEmpty) {
      return 'https://wordwall.net/ar/embed/$gameId?themeId=$themeId&templateId=$templateId&fontStackId=0';
    }

    // Fallback to url field
    final url = game['url'] as String?;
    return url;
  }
}
