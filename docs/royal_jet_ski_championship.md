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

## Current implementation status

### Implemented foundation
- The approved waterfront course has start, three checkpoint, and finish gates at Z=96, 111, 126, 141, and 148. The dedicated server now checks the server-simulated craft segment against the next gate plane in order, using the interpolated crossing point inside the buoy aperture and a bounded waterline height. Reverse travel, proximity without crossing, skipped planes, and out-of-aperture crossings do not advance progress.
- The standalone RoyalJetSki scene, client controller, and dedicated touch HUD are integrated into the city scene. Online boarding and dismounting use authenticated server requests and server-confirmed positions.
- The dedicated server validates bounded, sequenced, rate-limited throttle/brake/steering input. Clients never submit craft positions.
- The server simulates jet ski movement using the shared hydrodynamic motion contract, applies the rider transform, and sends authoritative craft snapshots to the rider.
- Remote-player snapshots include jet ski riding state and craft transforms, allowing other clients to render remote riders. Local prediction reconciles against server snapshots.
- Input timeout, independent launch slots, server-side mount/dismount lifecycle, and disconnect cleanup are covered by contract tests.
- The race lobby supports a server-owned roster of up to four participants, a separate spectator role, a five-second countdown, and a five-minute race timer.

### Remaining before the championship is playable
- The server now records a finisher only after the last gate plane is crossed in order; the finish time is measured with the server monotonic clock. Participants still on course when the five-minute timer expires are marked DNF, and a disconnect during the active round is recorded as DNF.
- The mounted-roster prerequisite remains enforced before countdown; locked participants cannot dismount during countdown or racing.
- The dedicated server sends each racer their validated gate progress and broadcasts a sanitized in-memory results board (racer slot, finish/DNF status, and server place). The jet ski HUD displays race state, gate progress, and round results in Arabic. Finish times are measured from the server monotonic clock; identical finish times share a rank using competition ranking (for example, 1, 1, 3). The board is not yet persisted; spectator camera experience and durable reward claims remain incomplete.
- Connect daily reward eligibility to a durable, atomic per-account claim record only after a server-verified final result exists; no cash reward is currently issued.
- Complete spectator camera selection and a rendered spectator experience; spectator registration and read-only role separation alone do not complete the viewing feature.
- Verify the course, collision boundaries, and actual rendered waterfront preview in the game scene.
- Run a real multi-client session against a dedicated server and test boarding, steering, remote visibility, checkpoint order, finish, spectator behavior, dismount, timeout, and disconnect.
- Verify the weekly schedule against Egypt daylight-saving changes before year-round production use.

Do not describe the championship as playable or multiplayer-validated until these remaining items and a real multi-client test are complete.

## Synchronized countdown and race timer
- The dedicated server changes a valid locked roster into a `countdown` phase for five seconds, then advances to `racing` using the server monotonic clock.
- The race timer runs for five minutes from the server's transition into `racing`; countdown time is excluded.
- The server moves the round to `finished` when the timer expires and notifies registered participants and spectators.
- A participant disconnect during `ready` or `countdown` reopens registration and clears the countdown deadline. Disconnects during a live race update the roster notification, but final race adjudication and DNF policy remain to be implemented.
- The timer and lobby phase do not themselves validate course progress or determine a winner.

## وضع مشاهدة السباق — اعتماد التصميم
- يمكن للاعبين غير المشاركين مشاهدة الجولة الجارية مباشرة؛ مثال ذلك أن يشارك لاعبان بينما يشاهد اللاعبان الآخران.
- المشاهد لا يُضاف إلى قائمة المتسابقين المقفلة، ولا يشغل أحد مقاعد المتسابقين الأربعة، ولا يستطيع إرسال مدخلات قيادة أو التأثير في نقاط التفتيش أو نتيجة السباق.
- نقطة المشاهدة الأساسية من الشاطئ الملكي، مع بث/مزامنة حالة الجت سكي ومواقع المتسابقين من الخادم إلى المشاهدين.
- تتضمن واجهة المشاهدة كاميرا اختيارية للتبديل بين المتسابقين ومتابعة السباق من زوايا مختلفة، مع إمكانية العودة إلى منظور الشاطئ.
- يجب أن تكون بيانات المشاهدة للقراءة فقط، وأن تستمر المشاهدة دون تغيير حالة الجولة أو إبطائها أو منح أفضلية لأي متسابق.
- أضيف إلى الخادم دور مشاهد منفصل بطلب صريح عبر `request_watch_jet_ski_race()`، ويمكن إيقافه عبر `request_stop_watching_jet_ski_race()`. تزال صفة المشاهد عند الخروج أو انقطاع الاتصال. يُرفض إدخال المتسابق ضمن دور المشاهدة، وإذا قرر المشاهد التسجيل قبل قفل الجولة تزال صفته كمشاهد أولًا.
- إشعارات حالة الجولة تُرسل الآن إلى المتسابقين والمشاهدين المسجلين، بينما تبقى أوامر الانضمام والبدء محكومة بقائمة المتسابقين فقط. المشاهد لا يستهلك أحد المقاعد الأربعة.
- أضيفت اختبارات عقد للتحقق من أن المتسابق لا يستطيع التحول إلى مشاهد، وأن اللاعب غير المشارك يستطيع طلب وضع المشاهدة، وأن معرف الاتصال غير الصالح يُرفض.
- هذا ينجز أساس صلاحيات المشاهدة وتسجيلها خادميًا فقط؛ لم تُنفذ بعد لقطات حالة الجت سكي المرئية للمشاهد، أو كاميرات التتبع، أو واجهة اختيار الكاميرا. كما لم يُثبت اختبار تعدد عملاء فعلي.



## مؤقتات البطولة الموحدة — خمس دقائق
- مدة الجولة الفعلية خمس دقائق (300 ثانية)، ويبدأ احتسابها من لحظة انتقال حالة الخادم من `countdown` إلى `racing`؛ لا تُحتسب ثواني العد التنازلي ضمن مدة السباق.
- عند انتهاء المؤقت، ينقل الخادم حالة الجولة إلى `finished` ويرسل إشعار انتهاء المدة إلى المتسابقين والمشاهدين.
- مهلة العودة إلى المسار بعد الخروج عنه خمس دقائق (300 ثانية) أيضًا، وهي مهلة مستقلة تبدأ عند اكتشاف الخادم خروج المتسابق عن المسار.
- أضيف ثابت مهلة الخروج واختبار قيمته، لكن لا يمكن تشغيل مؤقت الاستبعاد بعد لأن التحقق الخادمي من موقع الجت سكي/حدود المسار لم يُنفذ بعد. يجب ربط بدء المهلة وإلغائها واستبعاد اللاعب بمسار الحركة الخادمي قبل اعتبار هذه القاعدة مكتملة برمجيًا.
- يبقى العد التنازلي قبل الانطلاق خمس ثوانٍ، ولا يتغير بهذا القرار.


## مكافآت بطولة الجت سكي اليومية — اعتماد القاعدة
- تُخصص مكافآت نقدية كاش يومية لأصحاب المراكز الثلاثة الأولى فقط.
- لكل حساب استحقاق مكافأة واحدة كحد أقصى في اليوم؛ تكرار المشاركة في اليوم نفسه لا ينشئ استحقاقًا إضافيًا.
- إذا حقق اللاعب أكثر من مركز مؤهل في مسابقات اليوم نفسه، يُحتسب له أفضل مركز فقط وتُصرف له مكافأة واحدة عن اليوم.
- تُحدد المبالغ وقواعد الحساب والصرف لاحقًا ضمن الخطة الاقتصادية الشاملة للمدينة؛ لا تُضاف قيم مالية أو أرصدة افتراضية الآن.
- أضيفت إلى الخادم ثوابت/دوال مساعدة لتحديد أهلية المراكز الثلاثة ومفتاح الاستحقاق حسب هوية الحساب واليوم UTC، مع اختبارات عقد لهذه القاعدة.
- **حد التنفيذ الحالي:** لا يوجد حتى الآن نظام نتيجة سباق نهائية موثوق أو سجل مطالبات يومي مشترك ودائم مرتبط بقاعدة البيانات؛ لذلك لم يُفعّل صرف نقدي أو تسجيل استحقاق فعلي. يجب ربط ذلك لاحقًا بنتيجة يثبتها الخادم وبقيد ذري فريد لكل (الحساب، اليوم) في مخزن مركزي قبل إطلاق المكافآت.


## الجدول الأسبوعي الرسمي لبطولة الجت سكي
- أيام إقامة البطولة: السبت والاثنين والخميس أسبوعيًا.
- موعد الانطلاق المجدول: الساعة 8:00 مساءً بتوقيت مصر.
- يبدأ نطاق الإعلان المسبق قبل الموعد بـ15 دقيقة، أي من 7:45 مساءً في أيام البطولة.
- أضيفت ثوابت الجدول ودوال التحقق من يوم البطولة ونافذة الإعلان إلى الخادم، مع اختبارات عقد لهذه القواعد.
- **حد التنفيذ الحالي:** هذه الإضافة تثبت الجدول وتتحقق من أهلية اليوم ونافذة الإعلان برمجيًا، لكنها لا تطلق البطولة تلقائيًا ولا تبث إعلانًا داخل واجهة اللاعبين بعد. كما أن دخول اللاعبين وبدء الجولة ما زالا يعتمدان على استكمال تدفق السباق الخادمي وواجهة التسجيل. يستخدم الخادم حاليًا إعداد الساعة المصرية UTC+2 الموجود في المشروع؛ يجب تحديث/تكييف مصدر التوقيت عند تغير التوقيت الصيفي في مصر قبل الاعتماد التشغيلي طوال العام.


## Race roster safety prerequisite (2026-11-24)
- The server now refuses to start the synchronized countdown unless every locked roster member is authenticated and currently mounted on a jet ski.
- A locked participant cannot dismount during countdown or active racing; the server rejects that dismount request. Disconnect handling remains governed by the existing session cleanup and is not a substitute for finish adjudication.
- Added participant-gate contract coverage for fully mounted rosters, unmounted members, unauthenticated members, undersized rosters, and duplicate peer IDs.
- This closes the mounted-roster prerequisite only. Ordered server-side gate crossing, finish adjudication/results, race HUD, and live multi-client staging validation remain incomplete.

## Persistent race results and daily podium entitlement foundation (2026-11-24)
- Added a private append-only result ledger keyed by race and account, with a unique server event ID and server ID. A repeated identical event is idempotent; a conflicting result for the same racer/race is rejected.
- Added short-lived per-server nonce storage and a service-role-only recording RPC. The intended Edge Function boundary must verify the dedicated server HMAC before calling the RPC; authenticated clients cannot call either result recorder.
- The database derives the result day using `Africa/Cairo`, rather than trusting a client-provided date.
- Added one daily podium entitlement per account/day. If the player reaches a better place later that day, the stored entitlement is upgraded; ties in the same place retain the faster course time. DNF and fourth place do not qualify.
- Reward cash remains NULL and the entitlement remains `pending_configuration` until the city economy approves the amounts. This migration does not credit wallets or issue money.
- Applied and exercised the migration against the isolated `KING_OF_EGYPT_CITY_TEST` Supabase project. The SQL contract test file covers persistence, duplicate replay, conflicting results, nonce replay, Egypt-local daily uniqueness, best-place replacement, DNF/fourth-place exclusion, and client write/execute denial.
- **Not yet end-to-end:** the dedicated Godot server does not yet submit its final result payloads to a deployed HMAC-verifying Edge Function. The production Supabase project has not been changed. Do not describe race results as live-persisted until the server sender, Edge Function, and production migration are connected and staged together.

- Added the `jet-ski-race-results` Edge Function boundary: it validates the dedicated server's timestamped HMAC, strict result payload, finish-time window, and database nonce before forwarding the result through the service-role-only RPC. The function is configured with platform JWT verification disabled because it authenticates the server with HMAC itself.
- Added Edge Function contract tests to the GitHub Actions workflow. The function has been added to the repository but is not deployed to either Supabase project yet.

## Authoritative server result sender and durable retry outbox (2026-11-24)
- The dedicated Godot server now creates a unique race ID when the countdown transitions into the live race. Finish timestamps are derived from the server's race-start wall clock plus its monotonic finish duration; DNF timestamps are captured by the server at disconnect or time-limit resolution.
- Finalized finish and DNF rows are queued locally in `user://king_city_jet_ski_results_outbox.cfg` before submission. The outbox is restored on server startup and retains failed submissions; successful acknowledgements remove only the matching event. Retries use a fresh nonce while preserving the same event ID and result payload, so the database's idempotency checks can safely recognize delayed retries.
- The sender signs the exact JSON body with HMAC-SHA256 over `timestamp + newline + nonce + newline + raw_body`, matching the Edge Function verifier. Finish timestamps are sent as explicit UTC ISO-8601 values.
- The current server ranking policy is competition ranking: exact equal server finish times share a place, and the following place is skipped (for example, 1, 1, 3). The persistent entitlement keeps the best podium rank and, within the same rank, the faster finish time. No arbitrary lane/slot tie-break is introduced.
- Dedicated server runtime configuration required before results can be submitted:
  - `KING_CITY_SESSION_SERVER_ID`: the same registered server ID configured for the city session directory.
  - `KING_CITY_JET_SKI_RESULTS_HMAC_SECRET_B64`: a dedicated random secret of at least 32 decoded bytes, shared only with the matching `JET_SKI_RACE_SERVER_KEYS_JSON` entry in the Edge Function environment. Do not reuse the city-directory HMAC secret or commit the value.
  - Optional `KING_CITY_JET_SKI_RESULTS_URL`; otherwise the function URL is derived from the project's configured Supabase URL.
- The `jet-ski-race-results` Edge Function has now been deployed as version 1 to the isolated `KING_OF_EGYPT_CITY_TEST` project with JWT verification disabled because it authenticates the dedicated server through HMAC. The dedicated `JET_SKI_RACE_SERVER_KEYS_JSON` secret is not yet configured, so the function intentionally fails closed and cannot accept live race submissions yet. The production database has not been migrated and the production Edge Function has not been deployed. The next gate is to configure the dedicated test secret through Supabase project secrets, then run a signed end-to-end server result test before any production rollout.
