# إضافة FounderSecureStorage

هذه إضافة Godot Android Plugin v2. توفر singleton باسم `FounderSecureStorage` وتنفذ التخزين الآمن باستخدام Android Keystore.

## بناء AAR

من مجلد `android/plugins/founder_secure_storage`:

- `gradle :plugin:copyDebugAARToAddon`
- `gradle :plugin:copyReleaseAARToAddon`

ينبغي استخدام JDK 17 وAndroid SDK مع platform/build tools الملائمة لـ compileSdk 36، ومطابقة إصدار مكتبة Godot Android مع نسخة محرر المشروع. الإعداد الحالي مثبت على Godot `4.7.0.stable` ويجب تعديله إذا اختلفت نسخة التصدير الفعلية.

## تفعيل الإضافة

تم تفعيل ملف الإضافة في `project.godot` وضُبط Android Export Preset لاستخدام Gradle. بعد بناء ملفات AAR وظهورها في `addons/founder_secure_storage/bin/debug` و`release`:

1. افتح المشروع في Godot وثبّت Android Build Template من Project > Install Android Build Template إذا لم يكن مثبتًا.
2. تأكد من ظهور FounderSecureStorage ضمن Project Settings > Plugins.
3. أعد تصدير APK.

لا تفعّل الإضافة أو تصدر Android قبل وجود ملف AAR المناسب. لم يُبنَ AAR في هذه المرحلة.

## ربط جلسة المؤسس

يتولى `FounderAuthClient` حفظ `refresh_token` فقط عبر singleton `FounderSecureStorage` بعد نجاح OTP أو تدوير الرمز. عند تشغيل اللعبة، تُقرأ القيمة المشفرة ويُطلب تجديد الجلسة؛ وعند نجاح الاستعادة يُعاد طلب تذكرة اعتماد المؤسس من الخادم، الذي يظل صاحب القرار النهائي في منح الهوية. يتم تحديث الرمز المحفوظ بعد كل تجديد ناجح، وحذفه عند انتهاء الجلسة نهائيًا أو استدعاء `clear_auth_session()` لتسجيل الخروج.

إذا لم تكن الإضافة الأصلية محمّلة أو لم يكن AAR مبنيًا، فلن تتوفر الاستعادة الدائمة؛ تبقى الجلسة الحالية مؤقتة في الذاكرة. لا تُعد الميزة مثبتة عمليًا قبل بناء AAR وتصدير التطبيق واختبارها على جهاز Android فعلي.

## الواجهة

- `is_available()`
- `save_secret(alias, value)`
- `load_secret(alias)`
- `delete_secret(alias)`

لا تُسجل الرموز أو محتويات التخزين في السجلات. اختبر الحفظ والاستعادة والحذف وإبطال المفتاح على جهاز Android فعلي قبل اعتماد الميزة.
