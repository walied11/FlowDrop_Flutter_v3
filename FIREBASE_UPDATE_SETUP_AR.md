# إعداد تحديث FlowDrop عبر Firebase Realtime Database

التطبيق يقرأ العقدة `app_update` عبر REST من:
`https://walied-f4f1b-default-rtdb.firebaseio.com/app_update.json`
(غيّر الرابط من `lib/services/update_service.dart` إن استخدمت مشروعًا آخر).

## 1) أنشئ العقدة في Realtime Database

```json
{
  "latestVersion": "1.1.0",
  "minimumVersion": "1.0.0",
  "updateUrl": "https://رابط-الـAPK-المباشر",
  "forceUpdate": false,
  "message": "يتوفر إصدار جديد من FlowDrop. قم بالتحديث للحصول على آخر المزايا."
}
```

- `latestVersion`: أحدث إصدار منشور.
- `minimumVersion`: أقل إصدار مسموح له بالعمل (الأقدم منه يُجبر على التحديث).
- `updateUrl`: رابط تنزيل الـ APK أو صفحة التحديث (https).
- `forceUpdate`: `true` يجعل التحديث إجباريًا متى توفر إصدار أحدث.
- `message`: نص يظهر للمستخدم.

يقبل التطبيق أيضًا الأسماء البديلة: `minVersion`, `apkUrl`, `releaseNotes`, `update_url`, `update_force`, `update_message`.

## 2) قواعد القراءة (Rules)

اسمح بقراءة العقدة فقط، وادمج هذا مع قواعدك الحالية بدل استبدالها:

```json
{
  "rules": {
    "app_update": { ".read": true, ".write": false }
  }
}
```

## 3) رفع إصدار جديد

غيّر `version` في `pubspec.yaml` (مثال `1.1.0+2`) قبل البناء، ثم ارفع الـ APK وحدّث `latestVersion` و`updateUrl`.

## ملاحظات

- إصدار التطبيق الحالي يُقرأ تلقائيًا من `pubspec.yaml`.
- إذا تعذر الوصول إلى Firebase أو لم تُضبط العقدة، يعمل التطبيق بشكل طبيعي دون نافذة تحديث.
- لا يمنع التحديث الإجباري المستخدم من تثبيت نسخة أخرى يدويًا؛ هو يمنع فقط تجاوز الشاشة داخل التطبيق.
