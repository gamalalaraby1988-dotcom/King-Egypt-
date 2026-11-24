# إعداد خادم KING OF EGYPT CITY لبيئة الاختبار

هذه الوثيقة تخص مشروع Supabase الاختباري فقط:

- Project ID: `unwrlvyjrtdwobcktetd`
- Project URL: `https://unwrlvyjrtdwobcktetd.supabase.co`
- Edge Function: `city-session-directory`
- Function URL: `https://unwrlvyjrtdwobcktetd.supabase.co/functions/v1/city-session-directory`

لا تنسخ مفاتيح الإنتاج إلى بيئة الاختبار. ولا تضع أي سر حقيقي في المستودع أو ملفات المشروع.

## 1. متغيرات خادم Godot

تُمرر هذه القيم إلى عملية الخادم المخصص كمتغيرات بيئة:

| المتغير | القيمة / الاستخدام |
|---|---|
| `KING_CITY_SUPABASE_URL` | رابط مشروع الاختبار أعلاه |
| `KING_CITY_SUPABASE_PUBLISHABLE_KEY` | مفتاح Publishable الخاص بمشروع الاختبار فقط |
| `KING_CITY_SESSION_DIRECTORY_URL` | اختياري؛ رابط وظيفة الدليل أعلاه |
| `KING_CITY_SESSION_SERVER_ID` | معرّف ثابت، مثال: `city-egypt-staging-01` |
| `KING_CITY_SESSION_REGION` | `egypt` |
| `KING_CITY_SESSION_ENDPOINT` | عنوان WSS عام حقيقي؛ لا تستخدم قيمة وهمية |
| `KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64` | سر Base64 عشوائي مستقل، 32 بايت على الأقل بعد فك الترميز |
| `KING_CITY_GAME_PORT` | `2456` ما لم يحدد مزود الاستضافة منفذًا آخر |
| `KING_CITY_SESSION_CAPACITY` | `64` أو أقل |
| `KING_CITY_TLS_KEY_PATH` | مسار **المفتاح الخاص** لشهادة TLS |
| `KING_CITY_TLS_CERT_PATH` | مسار **شهادة TLS العامة** المطابقة للمفتاح |

تدعم نسخة الخادم في هذا الفرع أيضًا `KING_CITY_SUPABASE_URL` و`KING_CITY_SUPABASE_PUBLISHABLE_KEY` لجميع طلبات API الصادرة من الخادم، بما فيها التحقق من الحساب وطلبات التقدم. عند غيابهما تعود إلى إعدادات المشروع المعتادة. لذلك يجب ضبطهما معًا على مشروع TEST في بيئة الاختبار.

## 2. أسرار وظيفة city-session-directory

اضبط سر الدليل نفسه في إعدادات أسرار Edge Function باسم:

`CITY_SESSION_SERVER_KEYS_JSON`

بصيغة JSON، بحيث يكون المفتاح هو معرّف الخادم والقيمة هي سر Base64 المطابق:

```json
{"city-egypt-staging-01":"<DIRECTORY_HMAC_SECRET_BASE64>"}
```

يجب أن يطابق السر قيمة `KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64` حرفيًا. لا ترسل السر في المحادثة ولا تحفظه في Git.

## 3. أسرار نتائج بطولة الجت سكي

هذه آلية منفصلة عن سر دليل الجلسات. اضبط سرًا عشوائيًا مستقلًا في الخادم باسم:

`KING_CITY_JET_SKI_RESULTS_HMAC_SECRET_B64`

وفي أسرار وظيفة `jet-ski-race-results` باسم:

`JET_SKI_RACE_SERVER_KEYS_JSON`

وبالصيغة نفسها:

```json
{"city-egypt-staging-01":"<JET_SKI_RESULTS_SECRET_BASE64>"}
```

## 4. متطلبات التشغيل قبل التسجيل

- يجب أن يكون خادم Godot 4.7+ يعمل كعملية مستمرة باستخدام وسيط `--dedicated-server`.
- يجب أن تكون شهادة TLS صالحة للاسم الموجود في عنوان WSS، وأن يطابق المفتاح الخاص الشهادة.
- يجب أن يكون منفذ TCP المعلن متاحًا من الإنترنت، وأن يمرر إلى عملية Godot.
- لا يسجل الخادم نفسه في الدليل إلا بعد اكتمال متغيرات البيئة المطلوبة وبدء مستمع WSS.
- يرسل الخادم نبضات دورية، وتنتهي صلاحية التسجيل إذا توقف عن إرسالها.
- لا تسجل أي خادم بعنوان WSS غير مستضاف أو غير قابل للوصول.

## 5. حدود هذه المرحلة

نشر وظيفة الدليل في TEST لا ينشئ خادم Godot ولا يمنحه عنوان WSS عامًا. لا توجد في هذه الوثيقة بيانات اعتماد أو أسرار فعلية، ولا يتم هنا إنشاء خادم مستضاف. بعد توفير مضيف مستمر، يُختبر التسجيل والنبضات والحجز والاتصال الفعلي بعميلين على الأقل قبل إعلان تعدد اللاعبين جاهزًا.

**الإنتاج:** لا تغييرات على مشروع Supabase الإنتاجي ولا على إعداداته.
