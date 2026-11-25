# تنفيذ فصل بيئات البناء — KING OF EGYPT CITY

**التاريخ:** 2026-11-25  
**الفرع:** `feature/build-environment-separation-review`  
**طلب المراجعة:** PR #161 (Draft)  
**الحالة:** تغييرات الفصل الأساسية أُضيفت، والتحقق الآلي جارٍ؛ لم يتم الدمج.

## 1) ما تم تغييره

1. أضيفت Feature Overrides في `project.godot` لعنوان Supabase ومفتاح publishable ورابط OAuth:
   - الافتراضي ووسم `environment_production`: مشروع PRODUCTION.
   - وسم `environment_test`: مشروع TEST.
2. تم تعديل `PlayerAccountAuthClient` و`FounderAuthClient` لاستخدام `ProjectSettings.get_setting_with_override()` حتى يقرأ كل عميل إعداد البيئة المختار من preset التصدير.
3. قُسم `export_presets.cfg` إلى:
   - `Android TEST`: وسم TEST ومعرّف تطبيق Android منفصل `com.kingofegyptcity.game.test`.
   - `Android PRODUCTION`: وسم PRODUCTION ومعرّف التطبيق الأصلي `com.kingofegyptcity.game`.
4. أضيف اختبار عقدي `tests/build_environment_contract_test.gd` للتحقق من تطابق الوسوم وعناوين المشاريع والمفاتيح وطريقة قراءة الإعدادات.
5. أضيف الاختبار إلى سير عمل Godot CI، كما أصبح مسار Android debug يصدر preset TEST بدل preset عام غير محدد.

## 2) ملاحظة من أول تشغيل CI

أظهر أول تشغيل لـ Godot 4.7.2 أن `ProjectSettings.get_setting_with_override()` تقبل وسيطًا واحدًا فقط. تم تصحيح استدعاءات العميلين إلى الصيغة المطابقة للمحرك، ثم أُنشئ تحديث جديد على الفرع. يجب انتظار نتيجة تشغيل CI على آخر commit قبل اعتبار الاختبارات ناجحة.

## 3) حدود ما لم يكتمل

- لم يتم بعد تصدير APK TEST بنجاح على آخر commit.
- preset الإنتاج موجود ومحدد البيئة، لكن توقيع Release الإنتاجي وإصدار APK/AAB النهائي لم يُفعّلا؛ يحتاج ذلك إعداد مفاتيح توقيع آمنة خارج المستودع.
- لم يتم اختبار OAuth فعليًا على هاتف Android لكل بيئة.
- لم يتم نشر أو تعديل أي Edge Function، بما فيها `founder-entitlement`.
- لم تُنفذ أي SQL أو تغييرات على إعدادات Auth أو قواعد البيانات في TEST أو PRODUCTION.

## 4) ضوابط الأمان

- لم تُضف مفاتيح service-role أو مفاتيح توقيع Android أو مفاتيح توقيع تذاكر المؤسس.
- لا يتغير معرّف المؤسس أو حسابه أو صلاحياته.
- يبقى اختيار البيئة جزءًا من إعداد البناء، لا من بيانات اللاعب.
- PR #161 مسودة مفتوحة فقط؛ لا دمج دون موافقة صريحة.

## 5) وضع الفروع

- `main` مستهدف PR #161 عند الأساس `34d1c4e4a89dbb81cad2924d26665e83188fb307`، ولم يتم تعديله.
- `integration/safe-mainline-audit` لم يتم تعديله.
- التغييرات التشغيلية موجودة على `feature/build-environment-separation-review` فقط.
