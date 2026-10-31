# Code Editor - محرر الأكواد الذكي وبيئة التطوير المتكاملة

بيئة تطوير ومحرر أكواد متقدم لسطح المكتب والويب، مبني بالكامل من الصفر باستخدام تقنيات **Flutter & Dart**، يقدم أداءً فائقاً مع معمارية نموذجية (Modular Workbench Architecture) مستوحاة من المحررات العالمية مثل Visual Studio Code.

---

## 📋 بطاقة تعريف المشروع
* **اسم المشروع:** Code Editor
* **المسار:** `/home/osm/flutter_projects/code_editor/`
* **تصنيف المشروع:** Frontend / Desktop & Web Application
* **اللغات البرمجية:** Dart (100%), Flutter Framework
* **المنصات المستهدفة:** Linux, Windows, macOS, Web

---

## 🎯 فكرة المشروع وأهدافه
يهدف المشروع إلى توفير محرر أكواد خفيف، فائق السرعة، ومستقل تماماً، دون الاعتماد على مكوّنات خارجية ثقيلة (WebView أو محررات جاهزة معقدة). تم بناء نواة المحرر (Virtual Text Buffer) ليدعم:
- تحرير وتصفح الملفات البرمجية الضخمة بسلاسة بفضل التمرير الافتراضي (Virtualized Scrolling).
- إدارة التحديد المتعدد والمؤشرات (Multi-cursor support).
- تكامل مباشر مع بروتوكول خادم اللغة (LSP) لتوفير الإكمال التلقائي وتشخيص الأخطاء فورياً.
- نظام ملفات تفاعلي يستمع لتعديلات النظام لحظياً (File Watcher).
- طرفية أوامر مدمجة (Integrated Terminal) قادرة على تشغيل الأوامر والعمليات البرمجية مباشرة.

---

## 🏗 أجزاء وهيكلية المشروع (Architecture)
يتبع المشروع معمارية مجزأة دقيقة (Modular Workbench Architecture):

### 1. طبقة النواة (Core Layer):
* **Editor Buffer & Selection:** هيكل إدارة النصوص، الأسطر، المؤشرات والتحديد.
* **Syntax Highlighting & Lexer:** محرك تحليل وتلوين الشفرات البرمجية.
* **LSP Client (Language Server Protocol):** إدارة الاتصال بخوادم اللغات والتشخيصات (Diagnostics).
* **Execution & Terminal Engine:** تشغيل العمليات وإدارة الطرفية التفاعلية وقنوات الإخراج.
* **File System & Watcher:** استعراض المجلدات والملفات ومراقبة التغييرات الخارجية.
* **Configuration & Theme System:** إدارة تفضيلات المحرر وحفظ إعدادات المستخدم والثيمات.
* **Breadcrumbs:** مسار استدلالي للتنقل بين الرموز والدوال داخل الملف.

### 2. طبقة الواجهات (Workbench UI Layer):
* **Activity Bar:** الشريط الجانبي الأيقوني لاختيار اللوحات (المستكشف، البحث، الإعدادات).
* **Sidebar:** مستعرض الملفات التفاعلي.
* **Editor Area:** مساحة التحرير متعددة التبويبات مع أرقام الأسطر ومسطرة التشخيصات (Overview Ruler).
* **Bottom Panel:** لوحة سفلية قابلة للطي تحتوي على (Terminal, Output, Problems).
* **Status Bar:** شريط معلومات حي يعرض سطر وعمود المؤشر، الترميز، حالة LSP، ومساهمات الإضافات.

---

## 📦 المكتبات وحزم العمل المستخدمة (Dependencies)
| المكتبة | الإصدار | الغرض والاستخدام |
| :--- | :--- | :--- |
| `flutter` | SDK | إطار العمل الأساسي لبناء واجهة المستخدم والرسوميات عالية الأداء. |
| `shared_preferences` | `^2.5.4` | حفظ واسترجاع إعدادات وتفضيلات المستخدم محلياً (الثيم، خط المحرر، خيارات التنسيق). |
| `cupertino_icons` | `^1.0.8` | الأيقونات التفاعلية المستخدمة في الواجهة. |
| `flutter_test` (Dev) | SDK | كتابة واختبار اختبارات الوحدة (Unit Tests) واختبارات الواجهة (Widget Tests). |
| `flutter_lints` (Dev) | `^6.0.0` | تطبيق أفضل المعايير البرمجية الصارمة لكود Dart. |

---

## ⚙️ متطلبات وبيئة التشغيل (Prerequisites)
* **Flutter SDK:** الإصدار 3.24.0 أو أحدث.
* **Dart SDK:** الإصدار 3.5.0 أو أحدث.
* **أدوات تطوير سطح المكتب (Desktop C++ Toolchain):**
  * على Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
  * على Windows: Visual Studio مع أدوات C++ Desktop.
  * على macOS: Xcode Command Line Tools.

---

## 🚀 كيفية التثبيت والتشغيل بالتفصيل
```bash
# 1. الانتقال لمجلد المشروع
cd /home/osm/flutter_projects/code_editor

# 2. تحميل الحزم والمكتبات
flutter pub get

# 3. التحقق من سلامة الأكواد
flutter analyze

# 4. تشغيل التطبيق على بيئة سطح المكتب (Linux)
flutter run -d linux

# (اختياري) تشغيل على الويب
flutter run -d chrome

# 5. تشغيل الاختبارات الآلية
flutter test

# 6. بناء النسخة الإنتاجية
flutter build linux --release
```
