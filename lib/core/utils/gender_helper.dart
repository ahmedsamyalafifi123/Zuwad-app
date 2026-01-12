class GenderHelper {
  /// Check if the gender string represents a female.
  /// Handles Arabic and English variations, case-insensitive.
  static bool isFemale(String? gender) {
    if (gender == null) return false;

    final normalized = gender.trim().toLowerCase();

    return normalized == 'أنثى' ||
        normalized == 'انثى' ||
        normalized == 'female' ||
        normalized == 'woman' ||
        normalized == 'f';
  }

  /// Get the appropriate Arabic title for the teacher based on gender.
  /// Returns 'المعلمة' for female, 'المعلم' for male (default).
  static String getTeacherTitle(String? gender) {
    return isFemale(gender) ? 'المعلمة' : 'المعلم';
  }

  /// Get the appropriate Arabic formal title (Ustaz/Ustaza) based on gender.
  /// Returns 'المعلمة' for female, 'المعلم' for male (default).
  static String getFormalTitle(String? gender) {
    return isFemale(gender)
        ? 'المعلمة'
        : 'المعلم'; // Note: Masculine default could be 'المعلم' or 'المعلمة' depending on context, keeping as 'المعلم' for formal contexts matching previous logic
  }

  /// Get the avatar image asset path based on gender.
  static String getTeacherImage(String? gender) {
    return isFemale(gender)
        ? 'assets/images/woman.png'
        : 'assets/images/man.png';
  }
}
