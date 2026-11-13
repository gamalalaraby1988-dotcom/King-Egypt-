# ربط Godot بمصادقة Supabase التجريبية — قراءة فقط

## ما أُضيف
- `scripts/supabase_test_client.gd`: عميل Godot أصلي يستخدم `HTTPRequest` دون مكتبات خارجية.
- تسجيل دخول بالبريد وكلمة المرور عبر Supabase Auth.
- قبول UID حساب الاختبار المحدد فقط؛ أي حساب آخر يتم رفضه وتسجيل خروجه.
- تجديد الجلسة باستخدام refresh token.
- قراءة `public.get_my_test_economy_snapshot()` بعد المصادقة.
- تسجيل الخروج ومسح الرموز من الذاكرة.
- تسجيل العميل كـ Autoload باسم `SupabaseTestClient`.

## حدود الأمان
- المفتاح الموجود في العميل هو Publishable Key، وليس service_role أو Secret Key.
- لا تُحفظ كلمات المرور أو الرموز على القرص في هذا الإصدار.
- لا يرسل العميل معرف حساب اقتصادي؛ الدالة تستخرج الحساب المرتبط من `auth.uid()`.
- لا توجد أي دالة في العميل لتعديل Cash أو Chips أو Gems أو XP أو الملكية.
- عمليات تعديل الاقتصاد ما زالت محجوبة عن anon وauthenticated وservice_role مباشرة.
- هذا ربط اختبار مع حساب اصطناعي محدد، وليس نظام تسجيل/إنشاء حسابات عامًّا للعبة.

## طريقة الاستدعاء من مشهد تسجيل الدخول
يمكن استدعاء العميل من أي مشهد:
```gdscript
var ok: bool = await SupabaseTestClient.sign_in_with_password(email, password)
if ok:
    var snapshot: Dictionary = SupabaseTestClient.economy_snapshot
```

اربط إشارات `request_failed` و`auth_changed` و`economy_snapshot_received` بواجهة تسجيل الدخول/عرض الرصيد. لا تطبع كلمة المرور أو access token أو refresh token في السجل.

## حالة التحقق
- تحقق قاعدة البيانات: الدالة `public.get_my_test_economy_snapshot()` موجودة، وتسمح بـ EXECUTE للمستخدم authenticated وترفض anon.
- تحقق قاعدة البيانات: الدالة تستخدم `auth.uid()` لقراءة الحساب المرتبط فقط.
- تحقق قاعدة البيانات: جداول `game_test` ما زالت محمية بـ RLS، والجداول المالية الداخلية لا تملك سياسات قراءة للعميل.
- لم يُنفذ تسجيل دخول فعلي من نسخة Godot حتى الآن.
- لم يُشغّل محرر Godot أو Android export في بيئة العمل الحالية؛ لذلك لا يُعلن اجتياز تحليل GDScript أو APK.

## الخطوة التالية
إضافة واجهة تسجيل الدخول إلى تدفق التشغيل الحالي، ثم تشغيل المشروع في Godot 4.7.2 والتحقق من جلسة الاختبار وقراءة الرصيد قبل التفكير في أي عمليات كتابة خادمية.
