# استعادة جلسة المؤسس عبر Android Keystore

## الهدف
استعادة جلسة Supabase بعد إعادة تشغيل اللعبة دون كتابة access token أو refresh token كنص صريح داخل ملفات اللعبة.

## واجهة الربط
يستخدم `FounderAuthClient` Android native singleton باسم `FounderSecureStorage`، بالواجهة التالية:
- `is_available() -> bool`: التحقق من توفر التخزين الآمن.
- `save_secret(alias: String, value: String) -> bool`: حفظ السر.
- `load_secret(alias: String) -> String`: استعادة السر أو إرجاع نص فارغ.
- `delete_secret(alias: String) -> void`: حذف السر.

يُحفظ refresh token الخاص بالمؤسس فقط تحت الاسم `king_of_egypt_city.founder.refresh_token.v1`. لا يُحفظ access token؛ بعد تشغيل اللعبة يُستعاد refresh token ويُرسل إلى Supabase لتجديد الجلسة وتدوير الرمز. حساب اللاعب العادي يستخدم alias منفصلًا.

## تنفيذ Android الموجود في المستودع
أُضيف مصدر إضافة Godot Android Plugin v2 في:
- `android/plugins/founder_secure_storage/plugin/src/main/java/com/kingofegyptcity/security/FounderSecureStoragePlugin.kt`
- `android/plugins/founder_secure_storage/plugin/build.gradle.kts`
- `addons/founder_secure_storage/export_plugin.gd`
- `addons/founder_secure_storage/plugin.cfg`

التنفيذ يستخدم مفتاح AES-256-GCM غير قابل للتصدير داخل Android Keystore، وIV عشوائيًا لكل عملية تشفير، ويحفظ النص المشفر فقط في مساحة التطبيق الخاصة. كما يتعامل مع البيانات التالفة أو المفتاح غير المتاح بالفشل المغلق، ولا يكتب الرموز إلى السجلات.

الإضافة مفعلة في إعدادات المشروع، وAndroid Export Preset يستخدم Gradle. لكن وجود المصدر لا يعني أن الإضافة جاهزة داخل APK؛ ملفات AAR غير موجودة/لم تُبنَ بعد وفق حالة المستودع.

## بناء AAR وتفعيلها
من مجلد `android/plugins/founder_secure_storage`:
- `gradle :plugin:copyDebugAARToAddon`
- `gradle :plugin:copyReleaseAARToAddon`

المتطلبات الحالية: JDK 17 وAndroid SDK مع compileSdk 36، ومكتبة Godot Android المطابقة للإصدار المثبت في Gradle (`4.7.2.stable`). إذا تغير إصدار Godot، يجب توحيد إصدار المكتبة مع محرر المشروع وقوالب التصدير.

بعد بناء AAR:
1. تحقق من وجود `addons/founder_secure_storage/bin/debug/FounderSecureStorage-debug.aar` ونسخة release.
2. افتح المشروع في Godot وتأكد من ظهور FounderSecureStorage ضمن Project Settings > Plugins.
3. ثبّت Android Build Template إذا لم يكن مثبتًا.
4. صدّر APK ثم اختبر على جهاز Android فعلي.

لا تُفعّل اختبار التخزين الدائم باعتباره ناجحًا قبل بناء AAR وتصدير التطبيق والتحقق من الحفظ والاستعادة وتدوير refresh token وتسجيل الخروج.

## سلوك العميل عند غياب الإضافة
إذا لم يكن singleton محملًا أو لم يكن AAR متاحًا، لا يستخدم العميل تخزينًا نصيًا بديلًا؛ تبقى الجلسة الحالية في الذاكرة فقط، ولا تتوفر الاستعادة الدائمة بعد إغلاق اللعبة.

## متطلبات الأمان والتحقق
- لا تحفظ access token أو refresh token كنص صريح في ConfigFile أو SharedPreferences أو ملفات `user://`.
- لا تسجل الرموز أو محتوى التخزين في Logcat.
- عند رفض refresh token نهائيًا أو تسجيل الخروج، احذف الرمز المحفوظ ومفتاحه.
- عند انقطاع الشبكة أثناء الاستعادة، احتفظ بالرمز المشفر وأعد المحاولة؛ لا تعتبر فشل الشبكة تسجيل خروج.
- عند تدوير refresh token، تأكد من حفظ النسخة الجديدة بأمان وعدم إعادة استخدام القديمة.
- اختبر سلوك فقدان/إبطال مفتاح Keystore والبيانات التالفة، وتأكد من طلب تسجيل دخول جديد دون كشف الأسرار.
- لا يمنح وجود جلسة Auth أو تذكرة مؤسس محلية صلاحيات إدارة خادمية؛ يجب أن تتحقق الخدمات الحساسة من الصلاحية على الخادم.

## الحالة الحالية
- مصدر Android native plugin موجود في المستودع، وكذلك إضافة التصدير وملف إعدادها.
- إعدادات Godot تشير إلى تفعيل الإضافة وGradle Android export.
- لم يُبنَ AAR ولم يُثبت بعد نجاح الاستعادة الدائمة داخل APK.
- لم يتم اختبار هذه الوظيفة على جهاز Android فعلي في هذه المرحلة.
