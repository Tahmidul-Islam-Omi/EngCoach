/// Formatting for Bangladeshi mobile numbers.
///
/// Numbers are stored and sent as 11 plain digits — that is what bdapps
/// takes, what Firestore keys on, and what the learner typed. Formatting is
/// only ever for reading back, so it lives here rather than in any model.
extension PhoneFormat on String {
  /// `01712345678` → `+880 1712-345678`.
  ///
  /// Returns the string untouched if it is not 11 digits, so a partly typed
  /// number never renders as something misleading.
  String get asPrettyPhone =>
      length == 11 ? '+880 ${substring(1, 5)}-${substring(5)}' : this;
}
