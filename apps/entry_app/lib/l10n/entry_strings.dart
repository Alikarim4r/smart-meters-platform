import 'dart:ui';

import 'package:smart_meters_core/smart_meters_core.dart';

/// English/Arabic strings for the Entry app.
class EntryStrings {
  const EntryStrings(this.locale);

  final Locale locale;

  bool get isAr => locale.languageCode == 'ar';

  String _t(String en, String ar) => isAr ? ar : en;

  String get appTitle => _t('Meter Entry', 'إدخال العدادات');

  // Drawer / settings ----------------------------------------------------------
  String get settings => _t('Settings', 'الإعدادات');
  String get appearance => _t('Appearance', 'المظهر');
  String get themeLight => _t('Light', 'فاتح');
  String get themeDark => _t('Dark', 'داكن');
  String get themeSystem => _t('System', 'النظام');
  String get language => _t('Language', 'اللغة');
  String get languageEnglish => 'English';
  String get languageArabic => 'العربية';
  String get account => _t('Account', 'الحساب');
  String get changePassword => _t('Change password', 'تغيير كلمة المرور');
  String get newPassword => _t('New password', 'كلمة المرور الجديدة');
  String get confirmPassword => _t('Confirm password', 'تأكيد كلمة المرور');
  String get passwordUpdated => _t('Password updated', 'تم تحديث كلمة المرور');
  String get passwordTooShort =>
      _t('At least 8 characters', '٨ أحرف على الأقل');
  String get passwordsDoNotMatch =>
      _t('Passwords do not match', 'كلمتا المرور غير متطابقتين');
  String get signOut => _t('Sign out', 'تسجيل الخروج');
  String get aboutApp => _t('About', 'حول التطبيق');
  String get createdDevelopedBy =>
      _t('Created and developed by', 'تم الإنشاء والتطوير بواسطة');
  String get developerName => _t(
    'Eng. Ali Abdulkarim Elhassan',
    'المهندس: علي عبد الكريم الحسن',
  );
  String get developerPhone => '+974 3005 8899';
  String get developerEmail => 'Support@AliMind.com';
  String get save => _t('Save', 'حفظ');
  String get cancel => _t('Cancel', 'إلغاء');
  String get saving => _t('Saving…', 'جارٍ الحفظ…');
  String get retry => _t('Retry', 'إعادة المحاولة');

  // Shell / navigation ---------------------------------------------------------
  String get entryHeaderTitle =>
      _t('Meter Reading Entry', 'إدخال قراءات العدادات');
  String get backdated => _t('Backdated', 'تاريخ سابق');
  String get pickEntryDate =>
      _t('Entry date (backdating allowed)', 'تاريخ الإدخال (مسموح بتاريخ سابق)');

  // Sites ----------------------------------------------------------------------
  String get selectSite => _t('Select site', 'اختر الموقع');
  String get selectSiteHint => _t(
        'Only sites you are allowed to enter readings for are listed.',
        'تُعرض فقط المواقع المصرّح لك بإدخال القراءات فيها.',
      );
  String get loadingSites => _t('Loading sites…', 'جارٍ تحميل المواقع…');
  String get couldNotLoadSites =>
      _t('Could not load sites.', 'تعذّر تحميل المواقع.');
  String get noSites =>
      _t('No sites available for reading entry.', 'لا توجد مواقع متاحة للإدخال.');

  // Categories / types ---------------------------------------------------------
  String get selectMeterType => _t('Select meter type', 'اختر نوع العداد');
  String get selectMeterTypeHint => _t(
        'Only types with meters registered at this site are shown.',
        'تُعرض فقط الأنواع التي لها عدادات مسجّلة في هذا الموقع.',
      );
  String get metersOfType =>
      _t('Meters of this type at this site', 'عدادات هذا النوع في الموقع');
  String get loadingTypes =>
      _t('Loading meter types…', 'جارٍ تحميل أنواع العدادات…');
  String get couldNotLoadTypes =>
      _t('Could not load meter types.', 'تعذّر تحميل أنواع العدادات.');
  String get noMetersAtSite =>
      _t('No active meters found for this site.', 'لا توجد عدادات مفعّلة في هذا الموقع.');

  // Readings -------------------------------------------------------------------
  String get loadingMeters => _t('Loading meters…', 'جارٍ تحميل العدادات…');
  String get couldNotLoadMeters =>
      _t('Could not load meters.', 'تعذّر تحميل العدادات.');
  String get noMetersOfType => _t(
        'No active meters of this type at this site.',
        'لا توجد عدادات مفعّلة من هذا النوع في الموقع.',
      );
  String get readingsHint => _t(
        'Enter values for each meter. Tap the photo area for camera or gallery. '
        'Save stores locally and syncs when online.',
        'أدخل القيم لكل عداد. اضغط على منطقة الصورة للكاميرا أو الاستوديو. '
        'الحفظ يخزّن محليًا ويُزامن عند الاتصال.',
      );
  String get readingValue => _t('Reading value', 'قيمة القراءة');
  String get tapAddPhoto => _t('Tap to add photo', 'اضغط لإضافة صورة');
  String get photoRequired =>
      _t('Add photo (required)', 'أضف صورة (إلزامي)');
  String get clearReading => _t('Clear reading?', 'مسح القراءة؟');
  String clearReadingBody(String meterName) => _t(
        'Remove the value and photo for $meterName?',
        'إزالة القيمة والصورة لـ $meterName؟',
      );
  String get clear => _t('Clear', 'مسح');
  String get camera => _t('Camera', 'الكاميرا');
  String get gallery => _t('Gallery', 'الاستوديو');
  String get viewPhoto => _t('View photo', 'عرض الصورة');
  String get replaceCamera => _t('Replace (camera)', 'استبدال (كاميرا)');
  String get replaceGallery => _t('Replace (gallery)', 'استبدال (استوديو)');
  String get removePhoto => _t('Remove photo', 'إزالة الصورة');
  String get photo => _t('Photo', 'صورة');
  String get lastReading => _t('Last', 'السابق');
  String get fixInvalid =>
      _t('Fix invalid readings before saving.', 'صحّح القراءات غير الصالحة قبل الحفظ.');
  String get enterAtLeastOne => _t(
        'Enter at least one reading value to save.',
        'أدخل قيمة قراءة واحدة على الأقل للحفظ.',
      );
  String get highReading => _t('High reading', 'قراءة مرتفعة');
  String get review => _t('Review', 'مراجعة');
  String get confirm => _t('Confirm', 'تأكيد');
  String savedCount(int n) => isAr
      ? (n == 1
          ? 'تم حفظ قراءة واحدة (تُزامن عند الاتصال).'
          : 'تم حفظ $n قراءات (تُزامن عند الاتصال).')
      : (n == 1
          ? '1 reading saved (syncing if online).'
          : '$n readings saved (syncing if online).');

  // Card border legend ---------------------------------------------------------
  String get legendEmpty => _t('Incomplete', 'غير مكتمل');
  String get legendValue =>
      _t('Value + photo ready', 'قيمة وصورة جاهزة');
  String get legendPhoto => _t('Saved', 'تم الحفظ');

  // Profile --------------------------------------------------------------------
  String get profileSection => _t('My profile', 'ملفي الشخصي');
  String get fullName => _t('Full name', 'الاسم الكامل');
  String get companyName => _t('Company name', 'اسم الشركة');
  String get phone => _t('Phone number', 'رقم الهاتف');
  String get changePhoto => _t('Change photo', 'تغيير الصورة');
  String get addProfilePhoto => _t('Add profile photo', 'إضافة صورة شخصية');
  String get profileSaved => _t('Profile saved', 'تم حفظ الملف الشخصي');
  String get nameRequired =>
      _t('Full name is required', 'الاسم الكامل مطلوب');
  String get editProfile => _t('Edit profile', 'تعديل الملف');
  String get saveProfile => _t('Save profile', 'حفظ الملف');

  // Connectivity ---------------------------------------------------------------
  String get online => _t('Online', 'متصل');
  String get offline => _t('Offline', 'غير متصل');
  String get offlineHint => _t(
        'Offline mode: readings will sync automatically when connection returns.',
        'وضع عدم الاتصال: ستُزامن القراءات تلقائيًا عند عودة الاتصال.',
      );
  String lastSync(String time) =>
      _t('Last sync: $time', 'آخر مزامنة: $time');
  String syncedAt(String time) => _t('Synced $time', 'آخر مزامنة $time');
  String get syncNow => _t('Sync now', 'زامن الآن');
  String get sync => _t('Sync', 'مزامنة');
  String get syncFailed => _t('Sync failed', 'فشل المزامنة');
  String get noInternet =>
      _t('No internet connection.', 'لا يوجد اتصال بالإنترنت.');
  String get couldNotSyncReading => _t(
        'Could not sync reading. Try again later.',
        'تعذّر مزامنة القراءة. حاول لاحقاً.',
      );
  String get couldNotSyncPermission => _t(
        'Could not sync reading. Check date permission and try again.',
        'تعذّر مزامنة القراءة. تحقق من صلاحية التاريخ وحاول مجدداً.',
      );

  // Readings workspace ---------------------------------------------------------
  String get previousReading => _t('Previous', 'السابق');
  String get newReading => _t('New Reading', 'قراءة جديدة');
  String get consumption => _t('Consumption', 'الاستهلاك');
  String get takeMeterPhoto =>
      _t('Take Meter Photo', 'التقاط صورة العداد');
  String get retakePhoto => _t('Retake', 'إعادة التقاط');
  String get searchMeters =>
      _t('Search meters…', 'بحث في العدادات…');
  String get filterAll => _t('All', 'الكل');
  String get filterPending => _t('Pending', 'معلّق');
  String get filterDone => _t('Done', 'مكتمل');
  String get statusDone => _t('Done', 'مكتمل');
  String get statusPending => _t('Pending', 'معلّق');
  String get statusReview => _t('Review', 'مراجعة');
  String get statusLocal => _t('Saved', 'محفوظ');
  String completedOfTotal(int done, int total) =>
      _t('$done of $total completed', '$done من $total مكتمل');
  String metersFooter(int total, int done) =>
      _t('$total meters · $done completed', '$total عداد · $done مكتمل');
  String get saveAndSubmit =>
      _t('Save & Submit', 'حفظ وإرسال');
  String get formInvalid => fixInvalid;

  // Roles ----------------------------------------------------------------------
  String roleLabel(UserRole role) {
    switch (role) {
      case UserRole.technician:
        return _t('Technician', 'فني إدخال');
      case UserRole.siteAdmin:
        return _t('Site Admin', 'مشرف مواقع');
      case UserRole.superAdmin:
        return _t('Super Admin', 'مشرف عام');
      case UserRole.viewer:
        return _t('Viewer', 'مُشاهد');
      case UserRole.technicianRequest:
        return _t('Pending request', 'طلب قيد الاعتماد');
    }
  }

  String siteName(Site site) =>
      isAr && site.nameAr.trim().isNotEmpty ? site.nameAr : site.nameEn;

  String categoryName(MeterCategoryConfig category) {
    final ar = category.nameAr?.trim() ?? '';
    if (isAr && ar.isNotEmpty) return ar;
    return category.displayName;
  }

  String meterName(Meter meter) =>
      isAr && meter.nameAr.trim().isNotEmpty ? meter.nameAr : meter.nameEn;
}
