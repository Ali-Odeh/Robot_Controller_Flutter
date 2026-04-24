# Robot Arm & Mecanum Wheels Controller
## Flutter App — بديل App Inventor

---

## خطوات تشغيل المشروع

### 1. تثبيت Flutter (إذا مش عندك)
```
https://docs.flutter.dev/get-started/install/windows
```
اختر Windows → Android

### 2. فتح المشروع
```bash
cd robot_app
flutter pub get
```

### 3. بناء APK
```bash
flutter build apk --release
```
ملف الـ APK راح يكون في:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 4. نقل APK للجوال
انقله عبر USB أو اشاركه، ثم ثبّته (لازم تفعّل "مصادر غير معروفة" في إعدادات الجوال)

---

## طريقة الاستخدام

### ربط الـ HC-05:
1. اذهب لـ Bluetooth في إعدادات الأندرويد
2. اعمل Pair مع HC-05 (الرمز عادةً: 1234 أو 0000)
3. افتح التطبيق واضغط CONNECT
4. اختار HC-05 من القائمة

### التحكم:
- **أزرار الحركة**: اضغط مع الاستمرار للتحريك، ارفع إصبعك للإيقاف
- **سرعة المنصة**: سلايدر يرسل قيمة ×20 للأردوينو (30-99)
- **ذراع الروبوت**: اضغط مع الاستمرار لكل مفصل
- **سرعة الذراع**: سلايدر 100-250 (÷10 = delay بالـ ms)

---

## أوامر Bluetooth (تتطابق مع Arduino تمامًا)

| الأمر | الرقم |
|-------|-------|
| STOP | 0 |
| FORWARD | 2 |
| BACKWARD | 7 |
| SIDE LEFT | 4 |
| SIDE RIGHT | 5 |
| LEFT FWD | 1 |
| RIGHT FWD | 3 |
| LEFT BACK | 6 |
| RIGHT BACK | 8 |
| ROTATE LEFT | 9 |
| ROTATE RIGHT | 10 |
| SERVO 1 + | 16 |
| SERVO 1 - | 17 |
| SERVO 2 - | 18 |
| SERVO 2 + | 19 |
| SERVO 3 + | 20 |
| SERVO 3 - | 21 |
| SERVO 4 - | 22 |
| SERVO 4 + | 23 |
| SERVO 5 - | 24 |
| SERVO 5 + | 25 |
| SERVO 6 + | 26 |
| SERVO 6 - | 27 |
| PICKUP | 28 |
| DROP TRASH | 29 |
| DROP NOT TRASH | 30 |
