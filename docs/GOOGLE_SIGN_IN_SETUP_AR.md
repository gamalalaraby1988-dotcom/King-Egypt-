# إعداد تسجيل الدخول بزر Google واحد

هذه الخطوات مطلوبة في لوحة التحكم قبل اختبار Google OAuth على Android. لا تضع Client Secret أو أي مفتاح سري داخل Godot أو GitHub.

## 1. Google Cloud

1. افتح Google Cloud Console وأنشئ OAuth 2.0 Client من نوع **Web application**.
2. في Authorized redirect URIs أضف عنوان callback الخاص بمشروع Supabase:
   `https://lupmaktbymuaymhqsxxu.supabase.co/auth/v1/callback`
3. احتفظ بـ Client ID وClient Secret لإدخالهما في لوحة Supabase فقط.

## 2. Supabase Auth

1. افتح Authentication ثم Sign In / Providers ثم Google.
2. فعّل Google وأدخل Web Client ID وClient Secret من Google Cloud.
3. في URL Configuration أضف رابط التطبيق إلى Redirect URLs:
   `kingofegyptcity://auth-callback`
4. احفظ الإعدادات واختبر OAuth على جهاز Android.

## 3. الحفاظ على حساب اللاعب والشخصية

- يجب اختيار حساب Google الذي يحمل **نفس البريد الإلكتروني الموثّق** المرتبط بحساب اللاعب الأصلي.
- Supabase يدعم الربط التلقائي للهويات عندما يتطابق البريد الموثّق؛ إذا اختلف البريد فلا تفترض أن الحسابين أو الشخصيتين أصبحا هوية واحدة.
- بعد عودة OAuth، يتبادل التطبيق authorization code باستخدام PKCE ثم يستخدم جلسة Supabase نفسها لتحديث ملف اللاعب وطلب اعتماد المؤسس.
- لا ينشئ التطبيق ملف شخصية جديدًا بنفسه. لكن إذا دخل المستخدم ببريد Google مختلف، قد ينشئ Supabase مستخدم Auth جديدًا؛ لذلك لا تختَر بريدًا مختلفًا عند أول اختبار.
- يبقى قرار صلاحية المؤسس خادميًا فقط، ولا يمنح التطبيق صلاحية المؤسس لمجرد نجاح Google login.

## 4. متطلبات اعتماد المؤسس

اعتماد المؤسس لن يكتمل حتى تكون Edge Function `founder-entitlement` منشورة في مشروع الإنتاج، ويكون السر `FOUNDER_AUTH_EMAIL` مضبوطًا من لوحة Supabase. هذه الخطوات لم تُنفذ بواسطة هذا التغيير.

## 5. ما الذي يفعله التغيير البرمجي؟

- زر واحد: «المتابعة باستخدام Google».
- فتح OAuth في متصفح النظام والعودة إلى التطبيق عبر deep link.
- PKCE وتخزين verifier في Android secure storage.
- فحص اعتماد المؤسس تلقائيًا باستخدام جلسة اللاعب نفسها.
- لا توجد نافذة منفصلة لدخول المؤسس أو حقل بريد/رمز OTP في واجهة اللاعب.
- لا يتم تغيير إعدادات Supabase أو بيانات الإنتاج تلقائيًا.
