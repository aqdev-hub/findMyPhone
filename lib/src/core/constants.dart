class AppConstants {
  static const defaultTrustedContactsLimit = 10;
  static const maxTrustedContactsLimit = 20;
  static const nativeChannel = 'find_my_phone/native';

  /// The fixed code RESET/استرجاع sets the emergency code to. Must stay in
  /// sync with DEFAULT_RESET_CODE in SmsProcessorWorker.kt (native side).
  /// Documented in the SMS commands card and help dialog so both the phone
  /// owner and trusted contacts always know it — this is not a secret.
  static const defaultResetCode = 'RESET1234';
}
