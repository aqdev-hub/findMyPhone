/// All UI strings in both Arabic and English.
/// Usage: context.l10n.appName  OR  AppStrings.of(context).appName
class AppStrings {
  AppStrings(this.locale);
  final String locale; // 'ar' or 'en'

  bool get isAr => locale == 'ar';

  // ── App ─────────────────────────────────────────────────────────────────
  String get appName => isAr ? 'اعثر على هاتفي' : 'Find My Phone';
  String get tagline => isAr
      ? 'حماية وتتبع عبر رسائل SMS'
      : 'SMS-based protection & tracking';

  // ── Onboarding ───────────────────────────────────────────────────────────
  // Titles are split line-by-line to match the reference design exactly —
  // each screen's heading is deliberately two lines, not a wrapped paragraph.
  String get onboardTitle1Line1 => isAr ? 'احمِ هاتفك' : 'Protect your phone';
  String get onboardTitle1Line2 => isAr ? 'في كل الأوقات' : 'at all times';
  String get onboardSubtitle1 => isAr
      ? 'تطبيقنا يساعدك على حماية هاتفك من السرقة والوصول إليه حتى لو كان مغلقاً'
      : 'Our app helps protect your phone from theft and unauthorized access, even while locked.';

  String get onboardTitle2Line1 => isAr ? 'تحكم بهاتفك' : 'Control your phone';
  String get onboardTitle2Line2 => isAr ? 'عبر رسالة SMS' : 'via SMS';
  String get onboardSubtitle2 => isAr
      ? 'أرسل أوامر بسيطة من رقم موثوق وستتلقى استجابة فورية بهاتفك أينما كان.'
      : 'Send simple commands from a trusted number and get an instant response, wherever your phone is.';

  String get onboardTitle3Line1 => isAr ? 'استعد قبل أن' : 'Get ready before you';
  String get onboardTitle3Line2 => isAr ? 'تفقد هاتفك' : 'lose your phone';
  String get onboardItem1 => isAr
      ? 'أضف رقماً موثوقاً يمكنك الاعتماد عليه.'
      : 'Add a trusted number you can rely on.';
  String get onboardItem2 => isAr
      ? 'فعّل الأذونات اللازمة لحماية أفضل.'
      : 'Enable the necessary permissions for better protection.';
  String get onboardItem3 => isAr
      ? 'استلم تنبيهات عند تغيير الشريحة.'
      : 'Receive alerts when the SIM card changes.';
  String get onboardFooterSecure => isAr
      ? 'بياناتك آمنة وتبقى على جهازك فقط'
      : 'Your data is secure and stays only on your device';

  String get onboardNext => isAr ? 'التالي' : 'Next';
  String get onboardStart => isAr ? 'ابدأ الآن' : 'Get Started';
  String get onboardSkip => isAr ? 'تخطي' : 'Skip';

  // ── Navigation ───────────────────────────────────────────────────────────
  String get navDashboard => isAr ? 'الرئيسية' : 'Home';
  String get navContacts => isAr ? 'الموثوقون' : 'Contacts';
  String get navLogs => isAr ? 'السجل' : 'Logs';
  String get navSettings => isAr ? 'الإعدادات' : 'Settings';

  // ── Dashboard ────────────────────────────────────────────────────────────
  String get lastKnownLocation => isAr ? 'آخر موقع معروف' : 'Last Known Location';
  String get noLocationYet => isAr ? 'لا يوجد موقع محفوظ بعد.' : 'No location saved yet.';
  String get updateLocation => isAr ? 'تحديث الموقع الآن' : 'Update Location Now';
  String get openMap => isAr ? 'فتح في الخريطة' : 'Open in Map';
  String get liveTracking => isAr ? 'تتبع مباشر' : 'Live Tracking';
  String get battery => isAr ? 'البطارية' : 'Battery';
  String get stopAlarm => isAr ? 'إيقاف الإنذار' : 'Stop Alarm';
  String get locationUpdating => isAr ? 'جاري تحديث الموقع...' : 'Updating location...';
  String get locationUpdated => isAr ? 'تم تحديث الموقع.' : 'Location updated.';
  String get locationFailed => isAr ? 'فشل تحديث الموقع.' : 'Location update failed.';
  String get source => isAr ? 'المصدر' : 'Source';
  String get sourceGps => isAr ? 'GPS دقيق' : 'Precise GPS';
  String get sourceApprox => isAr ? 'تقريبي' : 'Approximate';
  String get sourceLast => isAr ? 'آخر موقع' : 'Last known';

  // ── SMS Commands ─────────────────────────────────────────────────────────
  String get smsCommands => isAr ? 'أوامر SMS' : 'SMS Commands';
  String get cmdLocate =>
      isAr ? 'يرسل الموقع الحالي الدقيق فور تحديثه.' : 'Sends the current precise location after refreshing it.';
  String get cmdSilent =>
      isAr ? 'يرسل الموقع بصمت بدون إشعار على الهاتف.' : 'Sends location silently, no notification on device.';
  String get cmdAlarm =>
      isAr ? 'يشغّل إنذار صوتي واهتزاز مستمر.' : 'Triggers loud alarm and continuous vibration.';
  String get cmdInfo =>
      isAr ? 'يرسل معلومات الجهاز: بطارية، شبكة، SIM.' : 'Sends device info: battery, network, SIM.';
  String get cmdLock =>
      isAr ? 'يقفل شاشة الجهاز فورًا عن بُعد.' : 'Locks the device screen instantly, remotely.';
  String get cmdReset => isAr
      ? 'يعيّن رمز طوارئ جديد بدون معرفة القديم — يتطلب أن يكون المُرسِل رقمًا موثوقًا مسجّلًا مسبقًا. يُنبَّه بقية جهات الاتصال الموثوقة تلقائيًا.'
      : 'Sets a brand-new emergency code without knowing the old one — requires the sender to be a pre-registered trusted number. Every other trusted contact is alerted automatically.';
  String get cmdLiveTrack => isAr
      ? 'يفعّل تتبعًا مباشرًا: يرسل تحديثات دورية للموقع عبر SMS حتى يوقفها صاحب الهاتف من داخل التطبيق — لا يمكن إيقافها عن بُعد.'
      : 'Activates live tracking: sends periodic location updates via SMS until the owner stops it from within the app — cannot be stopped remotely.';

  // ── Live tracking ────────────────────────────────────────────────────────
  String get liveTrackingActiveTitle =>
      isAr ? 'التتبع المباشر نشط' : 'Live Tracking Active';
  String get liveTrackingActiveDesc => isAr
      ? 'يُرسل التطبيق تحديثات دورية لموقع هذا الجهاز عبر SMS لمن فعّل التتبع.'
      : 'The app is sending periodic SMS location updates to whoever activated tracking.';
  String get stopLiveTracking => isAr ? 'إيقاف التتبع المباشر' : 'Stop Live Tracking';
  String get stopLiveTrackingConfirmTitle =>
      isAr ? 'إيقاف التتبع المباشر؟' : 'Stop live tracking?';
  String get stopLiveTrackingConfirmDesc => isAr
      ? 'سيتوقف إرسال تحديثات الموقع الدورية فورًا.'
      : 'Periodic location updates will stop immediately.';
  String get liveTrackingStopped =>
      isAr ? 'تم إيقاف التتبع المباشر.' : 'Live tracking stopped.';

  // ── Contacts ─────────────────────────────────────────────────────────────
  String get trustedContacts => isAr ? 'جهات الاتصال الموثوقة' : 'Trusted Contacts';
  String get addContact => isAr ? 'إضافة جهة اتصال' : 'Add Contact';
  String get contactName => isAr ? 'الاسم' : 'Name';
  String get contactPhone => isAr ? 'رقم الهاتف' : 'Phone Number';
  String get contactPhoneHint =>
      isAr ? 'مثال: 0512345678 أو +9665XXXXXXXX' : 'e.g. 0512345678 or +9665XXXXXXXX';
  String get contactRole => isAr ? 'الدور' : 'Role';
  String get rolePrimary => isAr ? 'أساسي' : 'Primary';
  String get roleSecondary => isAr ? 'ثانوي' : 'Secondary';
  String get roleBackup => isAr ? 'احتياطي' : 'Backup';
  String get roleAdditional => isAr ? 'إضافي' : 'Additional';
  String get rolePrimaryDesc =>
      isAr ? 'يتلقى تنبيهات SIM أولًا.' : 'Receives SIM alerts first.';
  String get roleSecondaryDesc =>
      isAr ? 'يتلقى التنبيهات ثانيًا.' : 'Receives alerts second.';
  String get roleBackupDesc =>
      isAr ? 'يتلقى التنبيهات إذا فشل الأساسي.' : 'Receives alerts if primary fails.';
  String get roleAdditionalDesc =>
      isAr ? 'يمكنه إرسال الأوامر فقط.' : 'Can send commands only.';
  String get deleteContact => isAr ? 'حذف جهة الاتصال' : 'Delete Contact';
  String get deleteConfirm => isAr ? 'هل تريد حذف' : 'Delete';
  String get noContacts => isAr ? 'لا توجد جهات اتصال موثوقة بعد.' : 'No trusted contacts yet.';
  String get ofMax => isAr ? 'من أصل' : 'of max';

  // ── Logs ─────────────────────────────────────────────────────────────────
  String get securityLog => isAr ? 'السجل الأمني' : 'Security Log';
  String get noLogs => isAr ? 'لا توجد أحداث مسجّلة بعد.' : 'No events logged yet.';

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settings => isAr ? 'الإعدادات' : 'Settings';
  String get settingsEmergencyCode => isAr ? 'رمز الطوارئ' : 'Emergency Code';
  String get settingsEmergencyCodeDesc =>
      isAr ? 'الرمز المُرسَل مع كل أمر SMS للتحقق من هويتك.' : 'Code sent with every SMS command to verify your identity.';
  String get currentCode => isAr ? 'الرمز الحالي' : 'Current Code';
  String get newCode => isAr ? 'الرمز الجديد' : 'New Code';
  String get confirmCode => isAr ? 'تأكيد الرمز الجديد' : 'Confirm New Code';
  String get codeHint =>
      isAr ? '6-12 حرفًا أو رقمًا إنجليزيًا (A-Z, 0-9)' : '6-12 English letters or digits (A-Z, 0-9)';
  String get showCode => isAr ? 'إظهار الرمز' : 'Show Code';
  String get hideCode => isAr ? 'إخفاء الرمز' : 'Hide Code';
  String get changeCode => isAr ? 'تغيير الرمز' : 'Change Code';
  String get codeChanged => isAr ? 'تم تغيير رمز الطوارئ بنجاح.' : 'Emergency code changed successfully.';
  String get codeStrength => isAr ? 'قوة الرمز' : 'Code Strength';
  String get strengthWeak => isAr ? 'ضعيف' : 'Weak';
  String get strengthFair => isAr ? 'متوسط' : 'Fair';
  String get strengthGood => isAr ? 'جيد' : 'Good';
  String get strengthStrong => isAr ? 'قوي جدًا' : 'Very Strong';
  String get strengthTooShort => isAr ? 'قصير جدًا' : 'Too short';

  String get settingsFeatures => isAr ? 'خيارات الميزات' : 'Feature Options';
  String get alarmSound => isAr ? 'الإنذار الصوتي' : 'Sound Alarm';
  String get alarmSoundDesc =>
      isAr ? 'عند تلقّي ALARM، يُشغّل صوتًا واهتزازًا مستمرًا.' : 'On ALARM command, plays loud sound and continuous vibration.';
  String get alertAllSim => isAr ? 'تنبيه جميع الجهات عند تغيير SIM' : 'Alert all contacts on SIM change';
  String get alertAllSimDesc =>
      isAr ? 'إذا كان مُعطَّلًا، يُرسل للأساسي والثانوي فقط.' : 'If disabled, alerts only primary and secondary contacts.';

  String get settingsSimGuard => isAr ? 'حارس SIM' : 'SIM Guard';
  String get simGuardDesc =>
      isAr ? 'يراقب تغيير شريحة SIM ويُرسل تنبيهًا فوريًا.' : 'Monitors SIM changes and sends immediate alerts.';
  String get simGuardLimit =>
      isAr ? 'قيد Android: لا يوجد بث صريح لتغيير SIM منذ API 22. يعتمد التطبيق على مقارنة البصمة عند كل تغيير في حالة الهاتف.'
           : 'Android limit: No explicit SIM change broadcast since API 22. App compares SIM fingerprint on every phone state change.';
  String get enableSimGuard => isAr ? 'تفعيل حارس SIM' : 'Enable SIM Guard';
  String get updateSimBaseline => isAr ? 'تحديث بصمة SIM الأساسية' : 'Update SIM Baseline';
  String get simBaselineUpdated => isAr ? 'تم حفظ بصمة SIM الحالية كمرجع.' : 'Current SIM saved as baseline.';

  String get settingsAutoStart =>
      isAr ? 'ضمان العمل في الخلفية' : 'Ensure Background Reliability';
  String get autoStartDesc => isAr
      ? 'بعض الأجهزة (خصوصًا Xiaomi وOppo وVivo وHuawei وغيرها) توقف عمل التطبيقات في الخلفية تلقائيًا، ما يمنع وصول أوامر SMS رغم منح كل الأذونات. فعّل السماح بالبدء التلقائي من إعدادات هاتفك.'
      : 'Some devices (especially Xiaomi, Oppo, Vivo, Huawei, and similar brands) silently stop apps from running in the background, even with all permissions granted — this can block SMS commands from being received. Allow autostart from your phone\'s settings.';
  String get openAutoStartSettings =>
      isAr ? 'فتح إعدادات البدء التلقائي' : 'Open Autostart Settings';
  String get autoStartNote => isAr
      ? 'إن لم تجد خيارًا مطابقًا، ابحث في إعدادات هاتفك عن "إدارة البطارية" أو "التطبيقات المحمية" أو "Autostart" وفعّله لهذا التطبيق يدويًا.'
      : 'If no matching screen opens, search your phone\'s settings for "Battery Manager", "Protected Apps", or "Autostart" and enable it for this app manually.';

  String get settingsDeviceAdmin =>
      isAr ? 'الحماية من إلغاء التثبيت' : 'Anti-Uninstall Protection';
  String get deviceAdminDesc => isAr
      ? 'يمنع إلغاء تثبيت التطبيق مباشرة، ويُفعّل أمر LOCK لقفل الشاشة عن بُعد.'
      : 'Prevents the app from being uninstalled directly, and enables the LOCK command to lock the screen remotely.';
  String get deviceAdminEnabled => isAr
      ? 'مُفعَّلة — لا يمكن إلغاء تثبيت التطبيق مباشرة.'
      : 'Active — the app cannot be uninstalled directly.';
  String get deviceAdminDisabled => isAr
      ? 'غير مُفعَّلة — يمكن لأي شخص يملك هاتفك إلغاء تثبيت التطبيق بسهولة.'
      : 'Inactive — anyone holding your phone can uninstall the app easily.';
  String get activateDeviceAdmin => isAr ? 'تفعيل الحماية' : 'Activate Protection';
  String get deviceAdminActivationFailed => isAr
      ? 'تعذّر فتح شاشة التفعيل. تأكد من السماح للتطبيق كمسؤول جهاز من الإعدادات.'
      : 'Could not open the activation screen. Allow this app as a device admin from Settings.';
  String get deviceAdminSystemWarning => isAr
      ? 'إلغاء تفعيل هذه الحماية يُزيل حماية السرقة من هذا الهاتف. إذا لم يكن هذا هاتفك، الرجاء إعادته لصاحبه.\n\nملاحظة: عند إلغاء التفعيل، سيتم إشعار جهات الاتصال الموثوقة تلقائيًا عبر SMS.'
      : 'Deactivating this removes theft protection from this phone. If this isn\'t your phone, please return it to its owner.\n\nNote: your trusted contacts will be automatically alerted via SMS when this is deactivated.';
  String get deviceAdminLimitNote => isAr
      ? 'ملاحظة: أندرويد يسمح دائمًا بإلغاء التفعيل يدويًا من الإعدادات، لكن هذه الخطوة الإضافية تُبطئ اللص وتُرسل تنبيهًا فوريًا لجهات اتصالك الموثوقة عند حدوثها.'
      : 'Note: Android always allows manual deactivation from Settings, but this extra step slows a thief down and immediately alerts your trusted contacts when it happens.';

  String get testLock => isAr ? 'اختبار قفل الجهاز' : 'Test Device Lock';
  String get testLockConfirmTitle => isAr ? 'قفل الشاشة الآن؟' : 'Lock screen now?';
  String get testLockConfirmDesc => isAr
      ? 'سيتم قفل شاشة هذا الجهاز فورًا لاختبار أمر LOCK. تابع بأمان.'
      : 'This will lock this device\'s screen immediately to test the LOCK command. Proceed safely.';
  String get testLockRequiresAdmin => isAr
      ? 'فعّل "الحماية من إلغاء التثبيت" أولًا من الإعدادات لاستخدام أمر القفل عن بُعد.'
      : 'Activate "Anti-Uninstall Protection" in Settings first to use the remote lock command.';

  // ── App Lock (tamper protection) ────────────────────────────────────────
  String get settingsAppLock => isAr ? 'حماية التطبيق من التلاعب' : 'App Tamper Protection';
  String get appLockDesc => isAr
      ? 'يطلب رمزًا لفتح التطبيق، حتى لا يستطيع من يحمل هاتفك تغيير الإعدادات.'
      : 'Requires a code to open the app, so whoever is holding your phone can\'t change settings.';
  String get appLockEnable => isAr ? 'تفعيل الحماية' : 'Enable Protection';
  String get appLockUnlock => isAr ? 'فتح' : 'Unlock';
  String get appLockUsingCustomPin => isAr
      ? 'يستخدم رمز قفل مخصص منفصل عن رمز الطوارئ.'
      : 'Using a dedicated lock code, separate from the emergency code.';
  String get appLockUsingEmergencyCode => isAr
      ? 'يستخدم رمز الطوارئ نفسه حاليًا (يمكنك تعيين رمز منفصل).'
      : 'Currently using your emergency code (you can set a separate one).';
  String get appLockSetCustomPin => isAr ? 'تعيين رمز مخصص' : 'Set a Custom Code';
  String get appLockChangeCustomPin => isAr ? 'تغيير الرمز المخصص' : 'Change Custom Code';
  String get appLockUseEmergencyCodeInstead =>
      isAr ? 'استخدام رمز الطوارئ بدلًا منه' : 'Use emergency code instead';
  String get appLockEnterCode => isAr ? 'أدخل رمز القفل' : 'Enter lock code';
  String get appLockNewCode => isAr ? 'الرمز المخصص الجديد' : 'New custom code';
  String get appLockWrongCode => isAr ? 'رمز غير صحيح.' : 'Incorrect code.';
  String get appLockSubtitle => isAr
      ? 'التطبيق مقفل — أدخل الرمز للمتابعة'
      : 'App is locked — enter the code to continue';
  String get appLockSave => isAr ? 'حفظ' : 'Save';
  String get appLockPinSaved =>
      isAr ? 'تم حفظ رمز القفل المخصص.' : 'Custom lock code saved.';

  String get settingsBattery => isAr ? 'إعدادات البطارية' : 'Battery Settings';
  String get batteryOptDesc =>
      isAr ? 'يضمن معالجة SMS الطارئة دون تأخير من Doze Mode.' : 'Ensures emergency SMS processing without Doze Mode delays.';
  String get batteryOptEnabled => isAr ? 'مُفعَّل — التطبيق يعمل بشكل موثوق.' : 'Enabled — app runs reliably in background.';
  String get batteryOptDisabled => isAr ? 'غير مُفعَّل — قد تتأخر الردود ساعات.' : 'Disabled — responses may be delayed by hours.';
  String get openBatterySettings => isAr ? 'فتح إعدادات البطارية' : 'Open Battery Settings';

  String get settingsPermissions => isAr ? 'الأذونات' : 'Permissions';
  String get requestAllPermissions => isAr ? 'طلب جميع الأذونات' : 'Request All Permissions';
  String get allPermissionsGranted =>
      isAr ? 'تم منح جميع الأذونات ✓' : 'All permissions granted ✓';
  String get somePermissionsMissing => isAr
      ? 'بعض الأذونات ما زالت مفقودة — افتح إعدادات التطبيق لمنحها يدويًا.'
      : 'Some permissions are still missing — open App Settings to grant them manually.';
  String get openAppSettings => isAr ? 'فتح إعدادات التطبيق' : 'Open App Settings';
  String get permGranted => isAr ? 'ممنوح ✓' : 'Granted ✓';
  String get permDenied => isAr ? 'مرفوض ✗' : 'Denied ✗';
  String get permPermanentlyDenied => isAr ? 'مرفوض دائمًا ✗' : 'Permanently Denied ✗';

  // Permission labels & descriptions
  String get permSmsLabel => isAr ? 'استقبال وإرسال SMS' : 'Receive & Send SMS';
  String get permSmsDesc =>
      isAr ? 'لاستقبال الأوامر والرد بالموقع.' : 'To receive commands and reply with location.';
  String get permLocationLabel => isAr ? 'الموقع الدقيق' : 'Precise Location';
  String get permLocationDesc =>
      isAr ? 'لتحديد موقع الجهاز عند أمر LOCATE.' : 'To determine device location on LOCATE command.';
  String get permBgLocationLabel => isAr ? 'الموقع في الخلفية' : 'Background Location';
  String get permBgLocationDesc =>
      isAr ? 'اختر "السماح دائمًا" حتى يعمل LOCATE عند قفل الشاشة.' : 'Select "Allow all the time" for LOCATE to work when screen is locked.';
  String get permPhoneLabel => isAr ? 'حالة الهاتف والـ SIM' : 'Phone State & SIM';
  String get permPhoneDesc =>
      isAr ? 'لاكتشاف تغيير SIM.' : 'To detect SIM changes.';
  String get permNotifLabel => isAr ? 'الإشعارات' : 'Notifications';
  String get permNotifDesc =>
      isAr ? 'لإظهار إشعار الإنذار المستمر.' : 'To show persistent alarm notification.';
  String get permVibrateLabel => isAr ? 'الاهتزاز' : 'Vibration';
  String get permVibrateDesc =>
      isAr ? 'يُمنح تلقائيًا من النظام.' : 'Automatically granted by the system.';
  String get permBatteryLabel => isAr ? 'تجاوز تحسين البطارية' : 'Ignore Battery Optimization';
  String get permBatteryDesc =>
      isAr ? 'يضمن عمل SMS الطارئ دون تأخير.' : 'Ensures emergency SMS works without delays.';

  String get settingsTest => isAr ? 'اختبار الميزات' : 'Test Features';
  String get testLocation => isAr ? 'اختبار الموقع' : 'Test Location';
  String get testLocationDesc =>
      isAr ? 'يحدّث الموقع ويحفظه في قاعدة البيانات.' : 'Updates and saves location to database.';
  String get testAlarm => isAr ? 'اختبار الإنذار' : 'Test Alarm';
  String get testSms => isAr ? 'اختبار السجل' : 'Test Log';
  String get testNow => isAr ? 'اختبر' : 'Test';
  String get guide => isAr ? 'دليل' : 'Guide';

  // ── Drawer ────────────────────────────────────────────────────────────────
  String get drawerAbout => isAr ? 'حول التطبيق' : 'About App';
  String get drawerContact => isAr ? 'تواصل بنا' : 'Contact Us';
  String get drawerHelp => isAr ? 'المساعدة' : 'Help & FAQ';
  String get drawerShare => isAr ? 'مشاركة التطبيق' : 'Share App';
  String get drawerOurApps => isAr ? 'تطبيقاتنا الأخرى' : 'Our Other Apps';
  String get drawerLanguage => isAr ? 'اللغة' : 'Language';
  String get drawerDarkMode => isAr ? 'الوضع الليلي' : 'Dark Mode';
  String get languageArabic => 'العربية';
  String get languageEnglish => 'English';

  // ── About ─────────────────────────────────────────────────────────────────
  String get aboutTitle => isAr ? 'حول التطبيق' : 'About App';
  String get aboutDesc => isAr
      ? 'اعثر على هاتفي تطبيق أمني يعمل عبر رسائل SMS دون الحاجة لإنترنت أو حساب.\n\nمُطوَّر بواسطة AQ Dev.'
      : 'Find My Phone is a security app that works via SMS without internet or an account.\n\nDeveloped by AQ Dev.';
  String get version => isAr ? 'الإصدار' : 'Version';

  // ── Errors ───────────────────────────────────────────────────────────────
  String get errCodeMismatch => isAr ? 'الرمز وتأكيده لا يتطابقان.' : 'Code and confirmation do not match.';
  String get errCodeInvalid =>
      isAr ? 'الرمز يجب أن يحتوي على 6-12 حرفًا أو رقمًا إنجليزيًا (A-Z / 0-9) فقط.'
           : 'Code must contain 6-12 English letters or digits (A-Z / 0-9) only.';
  String get errCodeWrong => isAr ? 'الرمز الحالي غير صحيح.' : 'Current code is incorrect.';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get confirm => isAr ? 'تأكيد' : 'Confirm';
  String get delete => isAr ? 'حذف' : 'Delete';
  String get save => isAr ? 'حفظ' : 'Save';
  String get close => isAr ? 'إغلاق' : 'Close';
  String get ok => isAr ? 'حسنًا' : 'OK';
  String get refresh => isAr ? 'تحديث' : 'Refresh';
  String get add => isAr ? 'إضافة' : 'Add';
}
