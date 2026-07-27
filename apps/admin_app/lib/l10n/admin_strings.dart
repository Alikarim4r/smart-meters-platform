import 'dart:ui';

/// English/Arabic strings for the admin app.
class AdminStrings {
  const AdminStrings(this.locale);

  final Locale locale;

  bool get isAr => locale.languageCode == 'ar';

  String _t(String en, String ar) => isAr ? ar : en;

  // App chrome ---------------------------------------------------------------
  String get appTitle => _t('Meter Admin', 'إدارة العدادات');

  String get structure => _t('Structure', 'الهيكل');
  String get organizations => _t('Organizations', 'الجهات');
  String get organizationsShort => _t('Orgs', 'الجهات');
  String get zones => _t('Zones', 'المناطق');
  String get sites => _t('Sites', 'المواقع');
  String get meters => _t('Meters', 'العدادات');
  String get network => _t('Network', 'الشبكة');
  String get users => _t('Users', 'المستخدمون');
  String get template => _t('Template', 'القالب');
  String get selectTemplate => _t('Select template', 'اختر القالب');
  String get manageSiteTypes => _t('Manage site types', 'إدارة أنواع المواقع');
  String get addDirectSite => _t('Add direct site', 'إضافة موقع مباشر');
  String get addSubZone => _t('Add sub-zone', 'إضافة منطقة فرعية');
  String get defaultSuggestedType =>
      _t('Default suggested site type', 'نوع الموقع الافتراضي المقترح');
  String get siteTypesNode => _t('Site types', 'أنواع المواقع');
  String get directSites => _t('Direct sites', 'مواقع مباشرة');
  String get selectTreeItem =>
      _t('Select an item in the tree', 'حدّد عنصرًا في الشجرة');
  String get addTypeInline => _t('Add new type', 'إضافة نوع جديد');
  String get openPolicy => _t('Policy settings', 'إعدادات السياسات');
  String get viewMeters => _t('View meters', 'عرض العدادات');
  String get parentZone => _t('Parent zone', 'المنطقة الأب');
  String get noParentZone => _t('Top-level zone', 'منطقة رئيسية');

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
  String get advancedTools => _t('Advanced tools', 'أدوات متقدمة');
  String get corrections => _t('Reading corrections', 'تصحيح القراءات');
  String get policySettings => _t('Policy settings', 'إعدادات السياسات');
  String get catalogAdvanced => _t('Catalog (advanced)', 'الفهرس (متقدم)');

  // Common actions -------------------------------------------------------------
  String get save => _t('Save', 'حفظ');
  String get cancel => _t('Cancel', 'إلغاء');
  String get close => _t('Close', 'إغلاق');
  String get edit => _t('Edit', 'تعديل');
  String get delete => _t('Delete', 'حذف');
  String get activate => _t('Activate', 'تفعيل');
  String get deactivate => _t('Deactivate', 'إيقاف');
  String get active => _t('Active', 'مفعّل');
  String get inactive => _t('Inactive', 'موقوف');
  String get retry => _t('Retry', 'إعادة المحاولة');
  String get search => _t('Search', 'بحث');
  String get all => _t('All', 'الكل');
  String get status => _t('Status', 'الحالة');
  String get saving => _t('Saving…', 'جارٍ الحفظ…');

  // List screens ---------------------------------------------------------------
  String get addOrganization => _t('Add organization', 'إضافة جهة');
  String get addZone => _t('Add zone', 'إضافة منطقة');
  String get addSite => _t('Add site', 'إضافة موقع');
  String get addMeter => _t('Add meter', 'إضافة عداد');
  String get addUser => _t('Add user', 'إضافة مستخدم');
  String get orgControlPermission =>
      _t('Full organization control', 'صلاحية التحكم بكامل الجهة');
  String get zoneControlPermission =>
      _t('Full zone control', 'صلاحية التحكم بكامل المنطقة');
  String get siteControlPermission =>
      _t('Site control permission', 'صلاحية التحكم بالموقع');
  String get registerNewAccount =>
      _t('Register new account', 'تسجيل حساب جديد');
  String get assignExistingAccount =>
      _t('Assign existing account', 'تعيين حساب موجود');
  String get assign => _t('Assign', 'تعيين');
  String get assignSuperAdminsHint => _t(
    'Registered Super Admin accounts',
    'حسابات السوبر أدمن المسجّلة',
  );
  String get assignAdminsHint => _t(
    'Registered Admin accounts',
    'حسابات الأدمن المسجّلة',
  );
  String get assignTechniciansHint => _t(
    'Registered technician accounts',
    'حسابات الفنيين المسجّلة',
  );
  String get assignViewersHint => _t(
    'Registered viewer accounts',
    'حسابات العرض المسجّلة',
  );
  String get scopeInheritHint => _t(
    'Organization Super Admins already control zones and sites. Zone Admins already control sites under their zone.',
    'من له تحكم كامل بالجهة (سوبر أدمن) يتحكم تلقائياً بالمناطق والمواقع. ومن له تحكم بالمنطقة يتحكم تلقائياً بمواقعها.',
  );
  String get inheritedAccessLabel =>
      _t('Inherited from parent scope', 'صلاحية موروثة من المستوى الأعلى');
  String get inheritedAccessCannotRemoveHere => _t(
    'Remove this access from the parent organization or zone',
    'أزل هذه الصلاحية من الجهة أو المنطقة الأب',
  );
  String get onlyOwnerManagesSuperAdmins => _t(
    'Only the platform owner can assign or remove Super Admins',
    'المالك فقط يمكنه تعيين أو حذف السوبر أدمن',
  );
  String get adminsAssignedBySuperHint => _t(
    'Regular admins are assigned by the organization Super Admin on zones',
    'الأدمن العادي يُعيَّن من سوبر أدمن الجهة على المناطق',
  );
  String get noEligibleAccounts => _t(
    'No eligible accounts available to assign',
    'لا توجد حسابات مؤهلة للتعيين',
  );
  String get accountsWithPermission =>
      _t('Accounts with permission', 'الحسابات التي لها الصلاحية');
  String get noAccountsInTab =>
      _t('No accounts in this tab yet', 'لا حسابات في هذا التبويب بعد');
  String get removeScopeAccess =>
      _t('Remove access', 'إزالة الصلاحية');
  String get searchOrganizations =>
      _t('Search organizations…', 'ابحث في الجهات…');
  String get searchZones => _t('Search zones…', 'ابحث في المناطق…');
  String get searchSites => _t('Search sites…', 'ابحث في المواقع…');
  String get searchMeters => _t('Search meters…', 'ابحث في العدادات…');
  String get searchUsers => _t('Name or email…', 'الاسم أو البريد…');

  // Forms ------------------------------------------------------------------------
  String get basicInformation => _t('Basic information', 'المعلومات الأساسية');
  String get englishName => _t('English name', 'الاسم بالإنجليزية');
  String get arabicName => _t('Arabic name', 'الاسم بالعربية');
  String get description => _t('Description', 'الوصف');
  String get code => _t('Code', 'الرمز');
  String get sortOrder => _t('Sort order', 'ترتيب العرض');
  String get organization => _t('Organization', 'الجهة');
  String get zone => _t('Zone', 'المنطقة');
  String get siteType => _t('Site type', 'نوع الموقع');
  String get siteTypes => _t('Site types', 'أنواع المواقع');
  String get siteTypesHint => _t(
    'Add types by typing English and Arabic names. These appear in Zones and Sites for this organization only.',
    'أضف الأنواع بكتابة الاسم بالإنجليزية والعربية. تظهر في المناطق والمواقع لهذه الجهة فقط.',
  );
  String get addSiteType => _t('Add type', 'إضافة نوع');
  String get typeNameEn => _t('Type (English)', 'النوع (إنجليزي)');
  String get typeNameAr => _t('Type (Arabic)', 'النوع (عربي)');
  String get noSiteTypesYet => _t(
    'No types yet — add at least one.',
    'لا أنواع بعد — أضف نوعًا واحدًا على الأقل.',
  );
  String get selectSiteType => _t('Select site type', 'اختر نوع الموقع');
  String get mixedOptional => _t('Optional — none', 'اختياري — بدون');
  String get selectOrganizationFirst =>
      _t('Select an organization first', 'اختر الجهة أولًا');
  String get selectOrganization => _t('Select organization', 'اختر الجهة');
  String get selectZones => _t('Select zones', 'اختر المناطق');
  String get selectSites => _t('Select sites', 'اختر المواقع');
  String get selectWholeZone => _t('Select whole zone', 'تحديد المنطقة كاملة');
  String get mustSelectSite => _t(
    'Select a whole zone or at least one site.',
    'حدّد منطقة كاملة أو موقعًا واحدًا على الأقل.',
  );
  String get defaultSiteType =>
      _t('Default site type', 'نوع المواقع الافتراضي');
  String get mixedAllTypes => _t('Mixed — all types', 'مختلط — كل الأنواع');
  String get locationAddress => _t('Location / address', 'الموقع / العنوان');
  String get editOrganization => _t('Edit organization', 'تعديل الجهة');
  String get editZone => _t('Edit zone', 'تعديل المنطقة');
  String get editSite => _t('Edit site', 'تعديل الموقع');
  String get editMeter => _t('Edit meter', 'تعديل عداد');
  String get meterDetails => _t('Meter details', 'تفاصيل العداد');
  String get meterCode => _t('Meter code', 'رمز العداد');
  String get categoryAndMeasurement =>
      _t('Category & measurement', 'الفئة والقياس');
  String get meterHasReadings =>
      _t('Meter has readings', 'العداد لديه قراءات');
  String get meterHasReadingsHint => _t(
    'This meter has readings. Category and unit cannot be changed.',
    'هذا العداد لديه قراءات. لا يمكن تغيير الفئة أو الوحدة.',
  );
  String get noZone => _t('No Zone', 'بدون منطقة');

  String get zoneFilter => _t('Zone filter', 'تصفية حسب المنطقة');
  String get allZones => _t('All zones', 'كل المناطق');
  String get allLevels => _t('All levels', 'كل المستويات');
  String get levelMain => _t('Main', 'رئيسي');
  String get levelSub => _t('Sub', 'فرعي');
  String get levelSubSub => _t('Sub-sub', 'فرعي الفرعي');
  String get meterLevel => _t('Level', 'المستوى');
  String get meterLevelHint => _t('Main → Sub', 'رئيسي ← فرعي');
  String get parentMainMeter => _t('Parent main meter', 'العداد الرئيسي الأب');
  String get parentMeterHint => _t(
    'Choose a main meter of the same category',
    'اختر عدادًا رئيسيًا من نفس الفئة',
  );
  String get createNewMainMeter =>
      _t('+ Create new main meter…', '+ إنشاء عداد رئيسي جديد…');
  String get poursIntoTank => _t('Pours into a tank', 'يصب في خزان');
  String get tank => _t('Tank', 'الخزان');
  String get tankHint => _t(
    'Select a registered tank or create one',
    'اختر خزانًا مسجلاً أو أنشئ واحدًا',
  );
  String get createNewTank => _t('+ Create new tank…', '+ إنشاء خزان جديد…');
  String get newTankName => _t('New tank name', 'اسم الخزان الجديد');
  String get allCategories => _t('All categories', 'كل الفئات');
  String get category => _t('Category', 'الفئة');
  String get site => _t('Site', 'الموقع');
  String get source => _t('Source', 'المصدر');
  String get unit => _t('Unit', 'الوحدة');

  // Water network map --------------------------------------------------------------
  String get networkImport => _t('Sync from meters', 'مزامنة من العدادات');
  String get networkAddAt => _t('Add on canvas', 'إضافة على اللوحة');
  String get networkAddMeter => _t('New meter', 'عداد جديد');
  String get networkAddTank => _t('New tank', 'خزان جديد');
  String get networkAddTanker => _t('Tanker discharge', 'صرف تانكر');
  String get networkAddGroundDrain => _t('Ground drain', 'صرف أرضي');
  String get networkHint => _t(
    'Drag nodes · tap → then tap target to connect · long-press empty area to add',
    'اسحب العقد · اضغط ← ثم الهدف للربط · اضغط مطولًا على الفراغ للإضافة',
  );
  String get networkEmpty => _t(
    'No network yet for this site. Sync meters or add nodes.',
    'لا شبكة بعد لهذا الموقع. زامن العدادات أو أضف عقدًا.',
  );
  String get networkNoSites => _t('No sites available.', 'لا مواقع متاحة.');
  String get networkSelectSite => _t('Select a site.', 'اختر موقعًا.');
  String get networkNoWaterCategory =>
      _t('Water category is not configured.', 'فئة المياه غير مُعدّة.');
  String get networkMissingCatalog => _t(
    'Add a source and unit for water before creating a meter.',
    'أضف مصدرًا ووحدة للمياه قبل إنشاء عداد.',
  );
  String get networkV2ReadOnly => _t('Network v2 · view', 'الشبكة v2 · عرض');
  String get networkV2Editing =>
      _t('Network v2 · editing', 'الشبكة v2 · تحرير');
  String get networkCreateWater =>
      _t('Create water network', 'إنشاء شبكة مياه');
  String get networkImportPreview =>
      _t('Preview legacy import', 'معاينة استيراد النظام القديم');
  String get networkImportApply => _t('Apply import', 'تطبيق الاستيراد');
  String get networkImportApplyDone =>
      _t('Import applied', 'تم تطبيق الاستيراد');
  String get networkImportDryRunHint => _t(
    'Dry-run only — nothing is written until you confirm.',
    'معاينة فقط — لا يُكتب شيء حتى التأكيد.',
  );
  String get networkImportMeters => _t('Meters to add', 'عدادات ستُضاف');
  String get networkImportTanks => _t('Tanks to add', 'خزانات ستُضاف');
  String get networkImportDrains => _t('Discharge points', 'نقاط الصرف');
  String get networkImportTankers =>
      _t('Tanker loading points', 'نقاط تحميل التانكر');
  String get networkImportConnections => _t('Connections', 'الاتصالات');
  String get networkImportSkipped => _t('Skipped / ignored', 'متجاهل');
  String get networkImportConflicts => _t('Conflicts', 'تعارضات');
  String get networkImportLegacyNodes => _t('Legacy nodes', 'عقد قديمة');
  String get networkImportLegacyEdges => _t('Legacy edges', 'حواف قديمة');
  String get networkImportAvailable => _t(
    'Draft is empty. Preview import from the legacy 031 map.',
    'المسودة فارغة. عاين الاستيراد من خريطة 031 القديمة.',
  );
  String get networkDraftEmpty =>
      _t('Draft has no assets yet.', 'المسودة بلا أصول بعد.');
  String get networkLegacy =>
      _t('Legacy 031 (old · read-only)', 'قديم 031 (للقراءة فقط)');
  String get networkLegacyReadOnlyHint => _t(
    'Comparison only — writing to 031 is disabled here.',
    'للمقارنة فقط — الكتابة إلى 031 معطّلة هنا.',
  );
  String get networkDraft => _t('Draft', 'مسودة');
  String get networkNoDraft =>
      _t('This network has no draft revision.', 'لا توجد مسودة لهذه الشبكة.');
  String get networkResetView => _t('Reset view', 'إعادة ضبط العرض');
  String get networkVersionConflict => _t(
    'Draft was changed elsewhere. Reload and try again.',
    'تم تعديل المسودة من مكان آخر. أعد التحميل وحاول مجددًا.',
  );
  String get networkPermissionDenied =>
      _t('You cannot manage this network.', 'لا يمكنك إدارة هذه الشبكة.');
  String get networkPorts => _t('Ports', 'المنافذ');
  String get networkInlets => _t('Inlets', 'المداخل');
  String get networkOutlets => _t('Outlets', 'المخارج');
  String get networkAddInlet => _t('Add inlet', 'إضافة مدخل');
  String get networkAddOutlet => _t('Add outlet', 'إضافة مخرج');
  String get networkRemovePort => _t('Remove port', 'حذف المنفذ');
  String get networkServiceType => _t('Water / service type', 'نوع المياه / الخدمة');
  String get networkSaveServiceType => _t('Save service type', 'حفظ نوع الخدمة');
  String get networkConnections => _t('Connections', 'العلاقات');
  String get networkModeView => _t('View', 'عرض');
  String get networkModeEdit => _t('Edit draft', 'تحرير المسودة');
  String get networkModeEditShort => _t('Edit', 'تحرير');
  String get networkPickFromGallery => _t('Gallery', 'المعرض');
  String get networkPickFromCamera => _t('Camera', 'الكاميرا');
  String get networkPickImageFailed =>
      _t('Could not open the image picker.', 'تعذر فتح منتقي الصور.');
  String get networkLockVersion => _t('Lock', 'القفل');
  String get networkAdd => _t('Add', 'إضافة');
  String get networkAddExistingMeter => _t('Existing meter', 'عداد موجود');
  String get networkAddNewMeter => _t('New meter', 'عداد جديد');
  String get networkAddExistingTank => _t('Existing tank', 'خزان موجود');
  String get networkAddNewTank => _t('New tank', 'خزان جديد');
  String get networkAddWaterSource => _t('Water source', 'مصدر مياه');
  String get networkAddPump => _t('Pump', 'مضخة');
  String get networkAddFilter => _t('Filter', 'فلتر');
  String get networkAddRo => _t('RO / treatment', 'تناضح / معالجة');
  String get networkAddJunction => _t('Junction', 'وصلة');
  String get networkAddConsumer => _t('Consumer', 'مستهلك');
  String get networkAddTankerLoading => _t('Tanker loading', 'تحميل تانكر');
  String get networkAddBuildingPortal => _t('Building portal', 'بوابة مبنى');
  String get networkAddCoolingTower => _t('Cooling tower', 'برج تبريد');
  String get networkAddChiller => _t('Chiller', 'مبرد (شبلر)');
  String get networkCreateView => _t('New view', 'عرض جديد');
  String get networkViewKind => _t('View kind', 'نوع العرض');
  String get networkValidate => _t('Validate', 'تحقق');
  String get networkPublish => _t('Publish', 'نشر');
  String get networkApproveChanges => _t('Approve changes', 'اعتماد التعديلات');
  String get networkPublishConfirm => _t(
    'Publish this draft? A new draft will be created after publish.',
    'نشر هذه المسودة؟ ستُنشأ مسودة جديدة بعد النشر.',
  );
  String get networkPublishDone => _t('Published', 'تم النشر');
  String get networkAutoSaved => _t('Auto-saved', 'محفوظ تلقائيًا');
  String get networkLoadFailed =>
      _t('Failed to load network.', 'تعذر تحميل الشبكة.');
  String get networkRetry => _t('Retry', 'إعادة المحاولة');
  String get networkOverview => _t('Overview', 'نظرة عامة');
  String get networkWaterTitle => _t('Water network', 'شبكة المياه');
  String get networkAddWithoutLink => _t('Add without link', 'إضافة بلا ربط');
  String get networkValidationErrors => _t('Validation errors', 'أخطاء التحقق');
  String get networkValidationWarnings =>
      _t('Validation warnings', 'تحذيرات التحقق');
  String get networkValidationOk => _t('Draft is valid', 'المسودة صالحة');
  String get networkUndo => _t('Undo', 'تراجع');
  String get networkRemoveFromView => _t('Remove from view', 'إزالة من العرض');
  String get networkDisconnect => _t('Disconnect', 'فصل');
  String get networkInspector => _t('Inspector', 'المفتش');
  String get networkConnectionKind => _t('Connection kind', 'نوع الاتصال');
  String get networkWaterType => _t('Water type', 'نوع المياه');
  String get networkTransportMode => _t('Transport mode', 'طريقة النقل');
  String get networkOperatingMode => _t('Operating mode', 'وضع التشغيل');
  String get networkConnectPorts => _t('Connect ports', 'ربط المنافذ');
  String get networkMeterPicker => _t('Choose meter', 'اختر عدادًا');
  String get networkTankPicker => _t('Choose tank', 'اختر خزانًا');
  String get networkSearch => _t('Search', 'بحث');
  String get networkStateNotInNetwork => _t('Not added', 'غير مضاف');
  String get networkStateInNetworkOtherView =>
      _t('In another view', 'في منظور آخر');
  String get networkStateInCurrentView =>
      _t('Already in network', 'موجود في الشبكة');
  String get networkUpstreamOptional =>
      _t('Upper supply source', 'مصدر التغذية الأعلى');
  String get networkDownstreamOptional =>
      _t('Meters it feeds', 'العدادات التي يغذيها');
  String get networkAddAndConnect => _t('Add and connect', 'إضافة وربط');
  String get networkFilterBuilding => _t('Building', 'المبنى');
  String get networkFilterStatus => _t('Meter status', 'حالة العداد');
  String get networkAll => _t('All', 'الكل');
  String get networkAddElement => _t('Add element', 'إضافة عنصر');
  String get networkElementDetails => _t('Element details', 'تفاصيل العنصر');
  String get networkConnectionProps =>
      _t('Connection properties', 'خصائص الاتصال');
  String get networkSaveConnection => _t('Save connection', 'حفظ الاتصال');
  String get networkDeleteConnection => _t('Delete connection', 'حذف الاتصال');
  String get networkInputs => _t('Inputs', 'المدخلات');
  String get networkOutputs => _t('Outputs', 'المخرجات');
  String get networkBuildingArea => _t('Building / area', 'المبنى / المنطقة');
  String get networkNone => _t('None', 'لا شيء');
  String get networkRemoveFromBoard =>
      _t('Remove from board', 'إزالة من اللوحة');
  String get networkDeleteNode => _t('Delete from network', 'حذف من الشبكة');
  String get networkDeleteNodeConfirm => _t(
    'This element and all of its connections will be removed from the draft. Continue?',
    'سيتم حذف هذا العنصر وجميع وصلاته من المسودة. هل تريد المتابعة؟',
  );
  String get networkCardImage =>
      _t('Card background image', 'صورة خلفية البطاقة');
  String get networkPickCardImage =>
      _t('Choose from device', 'اختيار من الجهاز');
  String get networkClearCardImage => _t('Remove image', 'إزالة الصورة');
  String get networkSaved => _t('Saved', 'تم الحفظ');
  String get networkReload => _t('Reload', 'إعادة تحميل');
  String get networkCutover =>
      _t('Finalize legacy cutover', 'إنهاء قطع النظام القديم');
  String get networkCutoverConfirm => _t(
    'Freeze legacy 031 writes for this site? This cannot be undone from the app.',
    'تجميد الكتابة إلى 031 لهذا الموقع؟ لا يمكن التراجع من التطبيق.',
  );
  String get networkLegacyFrozen =>
      _t('Legacy 031 · frozen', 'قديم 031 · مجمّد');
  String get networkLegacyFrozenHint => _t(
    'Legacy writes are frozen after cutover. Comparison only.',
    'كتابات النظام القديم مجمّدة بعد القطع. للمقارنة فقط.',
  );
  String get networkNameEn => _t('Name (EN)', 'الاسم (إنجليزي)');
  String get networkNameAr => _t('Name (AR)', 'الاسم (عربي)');
  String get networkMeterCode => _t('Meter code', 'رمز العداد');
  String get networkEditHint => _t(
    'Drag nodes · tap a port then another to connect',
    'اسحب العقد · اضغط منفذًا ثم آخر للربط',
  );
  String get networkNoCopyHint => _t(
    'A new meter record will not be created.',
    'لن يتم إنشاء نسخة جديدة من العداد.',
  );

  // Cards / dialogs -----------------------------------------------------------------
  String get deleteOrganizationTitle =>
      _t('Delete organization?', 'حذف الجهة؟');
  String get deleteZoneTitle => _t('Delete zone?', 'حذف المنطقة؟');
  String get deleteSiteTitle => _t('Delete site?', 'حذف الموقع؟');
  String get deleteUserTitle => _t('Delete user?', 'حذف المستخدم؟');
  String get forceDelete => _t('Force delete', 'حذف نهائي');
  String sitesCount(int count) => isAr
      ? (count == 1 ? 'موقع واحد' : '$count مواقع')
      : '$count site${count == 1 ? '' : 's'}';

  // Users --------------------------------------------------------------------------
  String get createUser => _t('Create user', 'إنشاء المستخدم');
  String get userCreated =>
      _t('User created and approved', 'تم إنشاء المستخدم واعتماده');
  String get accountSection => _t('Account details', 'بيانات الحساب');
  String get fullName => _t('Full name', 'الاسم الكامل');
  String get email => _t('Email', 'البريد الإلكتروني');
  String get password => _t('Password', 'كلمة المرور');
  String get invalidEmail => _t('Enter a valid email', 'أدخل بريدًا صحيحًا');
  String get roleAndPermissions => _t('Role & permissions', 'الدور والصلاحيات');
  String get role => _t('Role', 'الدور');
  String get roleTechnician => _t('Technician', 'فني إدخال');
  String get roleViewer => _t('Viewer', 'مُشاهد');
  String get roleSiteAdmin => _t('Site Admin', 'مشرف مواقع');
  String get roleSuperAdmin => _t('Super Admin', 'مشرف عام');
  String get roleTechnicianRequest => _t('Technician Request', 'طلب فني إدخال');
  String get allowBackdated =>
      _t('Allow backdated entries', 'السماح بالإدخال بتواريخ سابقة');
  String get allowBackdatedHint => _t(
    'Special permission: user can submit readings for past dates in the Entry app.',
    'صلاحية خاصة: يستطيع المستخدم إدخال قراءات لتواريخ سابقة في تطبيق الإدخال.',
  );
  String get assignSites => _t('Assign sites', 'إسناد المواقع');
  String get assignSitesHint => _t(
    'Choose the organization, then select whole zones or individual sites. At least one site is required.',
    'اختر الجهة، ثم حدّد مناطق كاملة أو مواقع فردية. يلزم موقع واحد على الأقل.',
  );
  String get assignScope => _t('Access scope', 'نطاق الوصول');
  String get assignScopeHint => _t(
    'Grant access to an organization, a zone (with optional child zones), or a single site. New sites under an inherited scope are included automatically.',
    'امنح الوصول لجهة أو منطقة (مع المناطق الفرعية اختياريًا) أو موقع واحد. المواقع الجديدة ضمن النطاق الموروث تُشمَل تلقائيًا.',
  );
  String get scopeOrganization => _t('Organization', 'جهة');
  String get scopeZone => _t('Zone', 'منطقة');
  String get scopeSite => _t('Site', 'موقع');
  String get appRole => _t('App role', 'دور التطبيق');
  String get inheritChildren => _t(
    'Include child zones / new sites',
    'شمول المناطق الفرعية والمواقع الجديدة',
  );
  String get inheritChildrenHint => _t(
    'When enabled, access covers current and future children under this scope.',
    'عند التفعيل، يشمل الوصول الأبناء الحاليين والمستقبليين تحت هذا النطاق.',
  );
  String get selectZone => _t('Select zone', 'اختر المنطقة');
  String get noZonesInOrg =>
      _t('No zones in this organization.', 'لا توجد مناطق في هذه الجهة.');
  String get noActiveSites =>
      _t('No active sites available.', 'لا توجد مواقع مفعّلة.');
  String get sitesSelected => _t('selected', 'محدد');
  String get pendingApprovals => _t('Pending approvals', 'بانتظار الاعتماد');
  String get approved => _t('Approved', 'معتمد');
  String get rejected => _t('Rejected', 'مرفوض');
  String get suspended => _t('Suspended', 'معلّق');
  String get allUsers => _t('All users', 'كل المستخدمين');
  String get approve => _t('Approve', 'اعتماد');
  String get reject => _t('Reject', 'رفض');
  String get roleFilter => _t('Role filter', 'تصفية حسب الدور');
  String get allRoles => _t('All roles', 'كل الأدوار');
  String get filterPending => _t('Pending', 'قيد الانتظار');
  String get filterApproved => _t('Approved', 'معتمد');
  String get filterRejected => _t('Rejected', 'مرفوض');
  String get filterSuspended => _t('Suspended', 'موقوف');
  String get noUsersMatch =>
      _t('No users match your filters', 'لا يوجد مستخدمون مطابقون');
  String get adjustFilters => _t(
    'Try adjusting search or filter criteria.',
    'جرّب تعديل البحث أو معايير التصفية.',
  );

  // Policy settings ------------------------------------------------------------------
  String get policyIntro => _t(
    'Configure operational rules for readings, photos, alerts, reports, and branding.',
    'اضبط القواعد التشغيلية للقراءات والصور والتنبيهات والتقارير والهوية.',
  );
  String get readOnlySuperAdmin => _t(
    'Read only — super admin can edit',
    'للقراءة فقط — التعديل للمشرف العام',
  );
  String get readingPolicy => _t('Reading policy', 'سياسة القراءات');
  String get allowLateReadings =>
      _t('Allow late readings', 'السماح بالقراءات المتأخرة');
  String get allowLateReadingsHint => _t(
    'When disabled, technicians are limited to today’s business date.',
    'عند الإيقاف، يقتصر الفنيون على تاريخ اليوم فقط.',
  );
  String get dailyCutoff =>
      _t('Daily reading cutoff time', 'وقت إقفال القراءة اليومية');
  String get cutoffHint => _t('HH:MM (Qatar time)', 'HH:MM (بتوقيت قطر)');
  String get backdatePerUser =>
      _t('Backdated entry (per user)', 'الإدخال بتواريخ سابقة (لكل مستخدم)');
  String get backdatePerUserHint => _t(
    'Granted per user from the Users tab — special permission.',
    'تُمنح لكل مستخدم من تبويب المستخدمين — صلاحية خاصة.',
  );
  String get correctionReason =>
      _t('Correction requires reason', 'التصحيح يتطلب سببًا');
  String get correctionReasonHint => _t(
    'Always enforced in the Admin corrections workflow.',
    'مطبّق دائمًا في مسار التصحيح داخل تطبيق الإدارة.',
  );
  String get photoPolicy => _t('Photo policy', 'سياسة الصور');
  String get photoRequired => _t('Photo required', 'الصورة إلزامية');
  String get photoRequiredHint => _t(
    'When enabled, Entry App blocks save/sync without a meter photo.',
    'عند التفعيل، يمنع تطبيق الإدخال الحفظ/المزامنة بدون صورة للعداد.',
  );
  String get missingPhotoSeverity =>
      _t('Missing photo alert severity', 'درجة تنبيه الصورة المفقودة');
  String get alertThresholds => _t('Alert thresholds', 'حدود التنبيهات');
  String get highConsumptionMultiplier =>
      _t('High consumption multiplier', 'مضاعف الاستهلاك المرتفع');
  String get criticalHighConsumptionMultiplier =>
      _t('Critical high consumption multiplier', 'مضاعف الاستهلاك الحرج');
  String get zeroConsumptionAlert =>
      _t('Zero consumption alert', 'تنبيه الاستهلاك الصفري');
  String get leakWarningDays =>
      _t('Possible leak warning days', 'أيام إنذار تسرب محتمل');
  String get leakCriticalDays =>
      _t('Possible leak critical days', 'أيام تسرب حرج محتمل');
  String get completionTargets => _t('Completion targets', 'مستهدفات الإنجاز');
  String get warningBelowPercent => _t('Warning below %', 'إنذار دون %');
  String get criticalBelowPercent => _t('Critical below %', 'حرج دون %');
  String get copPolicy => _t('COP policy', 'سياسة معامل الأداء COP');
  String get lowCopWarning =>
      _t('Low COP warning threshold', 'حد إنذار انخفاض COP');
  String get lowCopCritical =>
      _t('Low COP critical threshold', 'حد حرج لانخفاض COP');
  String get copMissingDataAlert =>
      _t('COP missing data alert', 'تنبيه نقص بيانات COP');
  String get reportSettings => _t('Report settings', 'إعدادات التقارير');
  String get reportFooterText => _t('Report footer text', 'نص تذييل التقرير');
  String get orgDisplayName =>
      _t('Organization display name', 'اسم الجهة الظاهر');
  String get includeAlertsDefault =>
      _t('Include alert section by default', 'تضمين قسم التنبيهات افتراضيًا');
  String get includePhotoDefault =>
      _t('Include photo indicator by default', 'تضمين مؤشر الصور افتراضيًا');
  String get brandingBasics => _t('Branding basics', 'أساسيات الهوية');
  String get logoUrl => _t('Logo URL (placeholder)', 'رابط الشعار (مؤقت)');
  String get logoUpload => _t('Logo upload', 'رفع الشعار');
  String get notAvailablePhase =>
      _t('Not available in this phase', 'غير متاح في هذه المرحلة');
  String get saveSettings => _t('Save settings', 'حفظ الإعدادات');
  String get resetDefaults => _t('Reset defaults', 'استعادة الافتراضي');
  String get resetDefaultsTitle =>
      _t('Reset to defaults?', 'استعادة الإعدادات الافتراضية؟');
  String get resetDefaultsBody => _t(
    'This restores operational policy values to platform defaults.',
    'سيعيد هذا قيم السياسات التشغيلية إلى افتراضيات المنصة.',
  );
  String get reset => _t('Reset', 'استعادة');
  String get settingsSaved =>
      _t('Policy settings saved.', 'تم حفظ إعدادات السياسات.');
  String get settingsResetDone => _t(
    'Policy settings reset to defaults.',
    'تمت استعادة الإعدادات الافتراضية.',
  );
}
