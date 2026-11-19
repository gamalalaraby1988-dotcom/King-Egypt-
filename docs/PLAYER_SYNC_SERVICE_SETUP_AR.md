# خدمة استقبال مزامنة اللاعب — إعداد ومراجعة

**الحالة:** ملفات مصدر مقترحة ضمن PR #38. لم تُطبّق migration على الإنتاج ولم تُنشر Edge Function.

## المكونات

- عميل Godot: `scripts/player_sync_client.gd` مع قائمة انتظار محلية `user://player_sync_outbox.cfg`، ومعرّفات UUID ثابتة، ودفعات حتى 50 حدثًا، وحذف الحدث من القائمة فقط بعد تأكيد الخادم. عند فشل الحفظ بعد القبول يمكن إعادة الإرسال بأمان بفضل مفتاح idempotency.
- ربط دورة جلسة المصادقة الحالية في `main.gd` مع العميل؛ يتم تمرير access token فقط، ولا يغادر refresh token مخزن Android الآمن.

- Migration: `20261119160000_player_sync_inbox.sql`
- Edge Function: `player-sync`
- RPC: `public.submit_player_sync_events(jsonb)`
- التخزين: `private.player_sync_events`

## حدود البيانات

تُقبل فقط أحداث:
- `setting_changed`: إعدادات مسموح بها (اللغة، حساسية الكاميرا، الصوت، تخطيط التحكم).
- `mission_progress_observed`
- `achievement_progress_observed`
- `activity_progress_observed`

أحداث التقدم مجرد ملاحظات غير موثوقة من العميل. لا تمنح خبرة أو مكافآت ولا تثبت إكمالًا. لا تقبل الخدمة المال أو الجواهر أو الرقائق أو الملكيات أو إيصالات الشراء أو صلاحيات المؤسس.

## الحماية

- Edge Function تبقي `verify_jwt = true`؛ بوابة Supabase تتحقق من JWT قبل تشغيل الدالة.
- المفتاح `sb_publishable` يرسل في `apikey` فقط، ورمز المستخدم في `Authorization: Bearer`.
- RPC تستخرج هوية الحساب من `auth.uid()` ولا تستقبل user_id من العميل.
- جدول التخزين في schema خاصة غير مكشوفة عبر Data API، ولا توجد صلاحيات مباشرة للأدوار العامة.
- RPC بصلاحية محددة، `SECURITY DEFINER` مع `search_path = ''`، وتتحقق من هوية المستخدم، وشكل الدفعة، وأنواع الأحداث ومفاتيح البيانات والقيم.
- قيد فريد `(user_id, event_id)` يجعل إعادة الإرسال آمنة من التكرار.
- الدفعة لا تتجاوز 50 حدثًا، وحجم payload لا يتجاوز 8 KiB لكل حدث.

## مفتاح التشغيل

- `player_sync/enabled` مضبوط على `false` افتراضيًا في `project.godot`.
- لن يرسل عميل Godot أي طلبات حتى بعد تسجيل الدخول ما لم يُفعّل هذا المفتاح صراحة بعد نشر قاعدة البيانات والدالة واختبارهما.
- إبقاء المفتاح مغلقًا يحافظ على قائمة الانتظار المحلية ويمنع استدعاء endpoint غير منشور.

## نشر آمن — غير منفذ

1. مراجعة SQL وEdge Function في PR.
2. تطبيق migration في بيئة تطوير أولًا.
3. التحقق من أن schema `public` تسمح باستدعاء RPC عبر Data API، وأن الدالة `player-sync` تستخدم JWT.
4. نشر Edge Function بعد موافقة مستقلة.
5. إجراء اختبار بحساب اختبار عادي: إرسال حدث مسموح، إعادة event_id نفسه، محاولة مستخدم غير مصادق، ومحاولة payload مالي/ملكية يجب رفضها.
6. تشغيل Supabase Security Advisors بعد تغييرات DDL.
7. لا تُربط اللعبة بإرسال أحداث الإنتاج قبل إتمام الاختبارات ومراجعة قواعد قبول تقدم المهام والمكافآت.

## ملاحظة API

من 30 أكتوبر 2026 لم تعد الجداول الجديدة في `public` تُعرّض تلقائيًا عبر Data API. هذا التصميم يخزن البيانات في schema `private` ويستدعي RPC ضمن `public`. يجب التأكد من أن `public` مفعّل ضمن exposed schemas وأن صلاحية EXECUTE للدالة تصل إلى authenticated؛ لا حاجة إلى تعريض schema `private`.

## التحقق

لم تُشغّل اختبارات SQL أو Edge Function أو Godot أو CI أو Gradle أو APK، ولم تُنشر أي تغييرات على Supabase.
