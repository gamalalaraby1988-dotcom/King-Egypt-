# بطولة الجت سكي الملكية — مواصفات التنفيذ المعتمدة

## القرار المعتمد
- الاسم: KING OF EGYPT JET SKI CHAMPIONSHIP.
- الحد الأدنى لبدء الجولة متسابقان، والحد الأقصى أربعة متسابقين.
- لا يبدأ العد التنازلي ولا تنطلق الجولة إذا كان عدد المسجلين أقل من متسابقين اثنين؛ عندها تظهر رسالة: «تحتاج المسابقة إلى متسابقين على الأقل لبدء الجولة».
- عند تسجيل 2 إلى 4 متسابقين، تُقفل قائمة المشاركين وتبدأ الجولة بعد عدّ تنازلي موحد؛ لا يُسمح بتجاوز أربعة مقاعد.
- السباق من خط انطلاق واضح إلى خط نهاية واضح.
- توجد نقاط تفتيش متتابعة على مسار بحري محدد بعوامات.
- يجب اجتياز كل نقطة بالترتيب؛ تجاوز نقطة أو قطع المسار لا يُحتسب وصولًا صحيحًا.
- الفائز أول متسابق يجتاز جميع نقاط التفتيش ثم خط النهاية.
- موقع النشاط: البحر المفتوح أمام الشاطئ الملكي، مع فصل مسار السباق عن منطقة السباحة وموقع السفينة الملكية.

## تعديل الواجهة البحرية المعتمد
- إزالة المارينا ومحطة المارينا وأحواض رسو اليخوت من التصور النهائي.
- تحويل موقع نادي اليخوت إلى نادٍ شاطئي ملكي بلا مرسى أو حوض يخوت.
- توسيع البحر المفتوح والشاطئ الملكي، والإبقاء على السفينة الملكية في البحر المفتوح.
- لا تُنقل معالم الواجهة البحرية الأخرى المعتمدة دون موافقة جديدة.

## مراحل التنفيذ البرمجي
1. **تخطيط المساحة أولًا:** إعادة توزيع المباني الستة لإخلاء مساحة البحر والشاطئ، ثم تحديث حدود الأرض والطرق ومناطق الماء لتجنب وجود أرض أو تصادمات مخفية تحت البحر.
2. **بناء المسار:** إنشاء خط الانطلاق، أربع خانات انتظار، عوامات تحديد المسار، بوابات نقاط التفتيش المرقمة، وخط النهاية. يجب أن تكون البوابات قابلة للعبور من الاتجاه الصحيح.
3. **مركبة الجت سكي:** إنشاء مشهد مستقل للجت سكي مع تحكم مائي مناسب، تسارع وتوجيه وفرملة، ومزامنة حالة المركبة والراكب.
4. **نظام الجولة الخادمي:** تسجيل من لاعبين اثنين إلى أربعة لاعبين موثّقين، ورفض بدء الجولة بأقل من اثنين، وقفل قائمة المشاركين عند طلب البدء، ثم عدّ تنازلي موحد والتحقق على الخادم من عبور كل لاعب لكل نقطة بالترتيب.
5. **النتيجة والإنصاف:** لا يُقبل زمن أو فوز مرسل من العميل. الخادم يحسب ترتيب الوصول، ويرفض اختصار المسار أو تكرار النقاط أو نتائج اللاعب المنقطع، ولا يمنح جائزة قبل اعتماد النتيجة.
6. **واجهة السباق:** إظهار المقاعد الأربعة، العد التنازلي، رقم نقطة التفتيش التالية، التقدم، والترتيب النهائي، مع دعم العربية والإنجليزية والهاتف.
7. **الاختبارات:** اختبار أربعة لاعبين فعليين على خادم مخصص، واختبار لاعب ينقطع، ونقطة يتم تجاوزها، والاقتراب من البوابة من الخلف، والتزامن، وإعادة تشغيل الجولة. لا يُعد اختبارًا محليًا بديلًا عن اختبار تعدد اللاعبين الحقيقي.

## قيود هندسية حالية يجب حلها قبل اعتماد الإحداثيات
- التخطيط الحالي يحتوي حوض ماء صغيرًا باسم `NileWaterfront` أبعاده 24×24 ومركزه (0, 0, 90)، وممرًا بحريًا عند Z=76، ومنطقة كرة يد شاطئية قرب (40, 0, 125).
- الأرض والطرق الحالية مبنية حول الحوض؛ تكبير سطح الماء وحده سيترك أرضًا وتصادمات تحت الماء. يجب تعديل الأرض والطرق والماء معًا.
- لا توجد حاليًا منظومة جت سكي أو سباق جت سكي موثقة في ملفات المشروع التي فُحصت. كما أن حركة اللاعب المتصلة بالخادم حاليًا تعتمد على المشي؛ لا يجوز اعتبار السباق متعدد اللاعبين جاهزًا قبل إضافة حركة مركبة خادمية موثوقة.
- لا تُستخدم مركبة السيارة الحالية كبديل شكلي للجت سكي، ولا تُحتسب نقاط التفتيش محليًا على العميل.

## شروط القبول
- كل جولة تضم من لاعبين اثنين إلى أربعة لاعبين.
- لا يمكن بدء العد التنازلي قبل تسجيل متسابقين اثنين على الأقل.
- لا يمكن تسجيل متسابق خامس في الجولة نفسها.
- لا يستطيع اللاعب إنهاء السباق دون عبور جميع نقاط التفتيش بالترتيب.
- النتيجة النهائية وترتيب الفائزين يصدران من الخادم فقط.
- لا تتغير بيانات الحساب أو الممتلكات أو الأصدقاء أو التقدم بسبب السباق.
- تُعرض معاينة المسار الفعلي المبني داخل اللعبة قبل اعتماد الدمج، ولا تُدمج تغييرات هذا العمل إلى `main` دون موافقة المؤسس.
## Layout preparation now present on the feature branch
- The six public buildings (cinema, royal theater, stadium, sports club, water city, DAILY ARCADE) are moved into two northern rows at Z=-120 and Z=-150 to clear the southern waterfront.
- The former marina terminal entry is removed. The former yacht-club building is relabeled as the Royal Beach Club; the building ID is retained for compatibility.
- The enclosed 24×24 basin and quay edges are replaced by a 120×72 open-sea surface centered at (0, 0, 114).
- The matching central southern ground collision slab is removed; east/west dry-land strips remain, and shoreline access roads are routed outside the water.
- The beach-handball court is relocated to the eastern dry beach at (90, 0, 130).
- A visible course layout is placed in the open sea: start at Z=96, checkpoints at Z=111, 126, and 141, finish at Z=148. Each gate has two marker buoys and a label.

## جسر الجت سكي الملكي — اعتماد التصميم
- اعتماد نسخ اللغة التصميمية لجسر/رصيف السفينة الملكية (العاجي والذهبي) وتطويرها إلى جسر أطول وأعرض.
- يبدأ الجسر من ممشى الواجهة البحرية الشرقية، ويمتد فوق البحر المفتوح إلى منصة الوصول البحرية.
- سطح واسع لعبور السيارات والمشاة، مع فصل ممر المشاة بحافة مرتفعة، وحواجز جانبية وأعمدة أمان وإرشاد ضوئي.
- في النهاية منصة وصول عريضة، وشريط توقف، ودرجات وصول، ودائرة مضيئة تمثل موضع التفاعل المقترح.
- أضيفت هندسة الجسر إلى `scripts/approved_city_layout.gd` على فرع العمل، مع وصلة طريق مركبات وممر مشاة من مدخل النادي الشاطئي، وتصادمات لسطح الجسر ومنصة الوصول والدرجات، وحواجز إرشادية عند المدخل.
- الدائرة والشريط والدرجات حاليًا عناصر مرئية فقط؛ لم يُنفذ بعد زر التفاعل أو فحص توفر الجت سكي أو الحجز الذري أو الركوب الفوري.
- لا تزال مراجعة نقطة البداية والنهاية والارتفاعات والتصادمات داخل Godot والتقاط معاينة من المشهد الفعلي مطلوبة قبل اعتماد الدمج.

## What this does not implement yet
- The course objects are visual markers only; they do not detect or validate crossings.
- A standalone jet ski scene, client controller, and touch HUD now exist, but they are not integrated into city spawning/boarding or authenticated multiplayer. The server-authoritative race countdown, vehicle movement/snapshots, checkpoint progression, finish validation, rewards, and race UI are still not implemented.
- No Godot test run has been observed for these new scene changes. The PR remains a draft and must be reviewed and tested before any merge.


## Current watercraft foundation (implementation in progress)
- Added an independent RoyalJetSki scene and controller. Its motion uses forward thrust, speed-dependent steering authority, lateral water damping, water resistance, and gentle buoyancy bob; it does not reuse the car's ground-contact or tire-steering physics.
- Added a dedicated touch HUD with drive, brake, steering, and right-side drag camera input.
- Added a headless contract test for steering authority and water-resistance behavior, and wired it into the Godot CI workflow.
- This is a reusable client-side vehicle foundation only. It is not yet spawned from the Royal Beach Club/bridge, does not yet mount the player's avatar, and is not yet connected to authenticated server movement.
- The synchronized countdown, server-owned jet ski movement, four-player vehicle snapshots, ordered checkpoint crossing validation, finish adjudication, race results/rewards, and final production-scene preview remain required before the championship can be considered playable.
- Do not describe the watercraft as multiplayer-ready until server authority and a real multi-client test are implemented.
