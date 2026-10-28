# تحليل الهيكل التصميمي للواجهة الرئيسية لمحرر الأكواد (دراسة مرجعية: VS Code Workbench)

تم إعداد هذا المستند كمرجع تحليلي وتصميمي معماري لبناء واجهة محرر أكواد متقدم وقابل للتوسع لأي لغة برمجية، بالاستناد إلى الكود المصدري الرسمي لـ **Visual Studio Code** (`/home/osm/Downloads/vscode-main/vscode-main`).

---

## 1. المدخل العام والمعمارية الكلية (Workbench Overview)

في بنية VS Code، تُعرف الواجهة المرئية بالكامل باسم **Workbench** (`vs/workbench`).  
تعتمد الواجهة على نموذج تقسيم شبكي هرمي ثنائي الأبعاد يُدار بواسطة محرك شبكي يُدعى `SerializableGrid` (`vs/base/browser/ui/grid/grid.ts`) وفئة التحكم الرئيسية `Layout` (`vs/workbench/browser/layout.ts`).

### المبدأ الأساسي للتخطيط (The Grid Concept)

الواجهة ليست مجرد عناصر مكدسة (Stack) أو مصفوفة رأسية ثابتة، بل هي **شجرة تقسيم مرنة (Layout Tree / Grid)**:

- **العقد الجذرية (Root Branch):** شريحة رأسية (`Orientation.VERTICAL`) تنقسم إلى 3 صفوف رئيسية:
  1. **القسم العلوي:** شريط العنوان (`TitleBar`) والشريط التحذيري (`Banner`).
  2. **القسم الأوسط (Middle Section):** شريحة أفقية (`Orientation.HORIZONTAL`) تضم أشرطة الأدوات الجانبية والمحرر واللوحات السفلية.
  3. **القسم السفلي:** شريط الحالة (`StatusBar`).

```
+-----------------------------------------------------------------------------------+
|                            TitleBar (شريط العنوان والتحكم)                         |
+-----------------------------------------------------------------------------------+
|                            Banner (الإشعارات والبانرات العلوية)                   |
+----+-------------------+------------------------------------+---------------------+
| A  |                   |                                    |                     |
| c  |    Primary        |           Editor Area              |    Secondary        |
| t  |    SideBar        |       (مساحة التحرير الرئيسية)      |     SideBar         |
| i  |  (الشريط الجانبي  |   Tabs + Breadcrumbs + CodeEditor  |  (Auxiliary Bar)    |
| v  |     الرئيسي:      |                                    |   (الشات / المساعد   |
| i  |   الملفات/البحث)  +------------------------------------+    / المخطط الهيكلي) |
| t  |                   |         Panel (اللوحة السفلية:     |                     |
| y  |                   |     Terminal, Output, Problems)    |                     |
+----+-------------------+------------------------------------+---------------------+
|                            StatusBar (شريط الحالة السفلي)                         |
+-----------------------------------------------------------------------------------+
```

---

## 2. تفكيك المكونات الأساسية (The Core Parts Architecture)

في ملف تعريف الخدمات `vs/workbench/services/layout/browser/layoutService.ts`، تُعرّف الأجزاء الرئيسية للمحرر كـ `Parts`:

```typescript
export const enum Parts {
    TITLEBAR_PART     = 'workbench.parts.titlebar',     // شريط العنوان
    BANNER_PART       = 'workbench.parts.banner',       // البانر
    ACTIVITYBAR_PART  = 'workbench.parts.activitybar',   // شريط الأنشطة
    SIDEBAR_PART      = 'workbench.parts.sidebar',       // الشريط الجانبي الأيسر
    PANEL_PART        = 'workbench.parts.panel',         // اللوحة (الطرفية/المخرجات)
    AUXILIARYBAR_PART = 'workbench.parts.auxiliarybar',  // الشريط الجانبي الأيمن
    EDITOR_PART       = 'workbench.parts.editor',        // مساحة المحرر
    STATUSBAR_PART    = 'workbench.parts.statusbar'      // شريط الحالة
}
```

كل جزء من هذه الأجزاء يرث من فئة تجريدية تدعى `Part` (`vs/workbench/browser/part.ts`)، وتوفر:

- دورة حياة منظمة: `create(parent)`, `layout(dimension)`, `setVisible(boolean)`, `dispose()`.
- تخطيط داخلي يتكون من 4 طبقات:
  - `HeaderArea`
  - `TitleArea`
  - `ContentArea`
  - `FooterArea`

---

### (1) شريط العنوان `TitleBar` (`parts/titlebar/`)

لم يعد مجرد شريط عنوان لنظام التشغيل، بل تحول في المحررات الحديثة إلى مركز تحكم تفاعلي:

- **عناصر التحكم بالنوافذ (Window Controls):** الإغلاق، التكبير، التصغير (مخصصة ومدمجة مع النظام Native/Custom).
- **قائمة التطبيق المدمجة (MenuBar Control):** (File, Edit, Selection, View, Go, Run, Terminal, Help).
- **مركز الأوامر (Command Center):** شريط بحث في المنتصف يتيح البحث السريع في الملفات وتنفيذ الأوامر (Command Palette `Ctrl+Shift+P`).
- **أزرار التحكم بالتخطيط (Layout Controls):** أيقونات سريعة لإظهار/إخفاء الشريط الجانبي، الطرفية، وشريط المساعد الذكي.

---

### (2) شريط الأنشطة `ActivityBar` (`parts/activitybar/`)

- **الوظيفة:** شريط أيقونات رفيع (عرض قياسي 48px).
- **محتواه:**
  - **أيقونات العرض الرئيسية (Top Actions):**
    - مستكشف الملفات (File Explorer).
    - البحث الشامل (Global Search).
    - إدارة الإصدارات (Source Control / Git).
    - التشخيص وتصحيح الأخطاء (Run & Debug).
    - إدارة الحزم والإضافات (Extensions).
  - **أيقونات الإدارة السفلية (Bottom Actions):**
    - الحسابات والملفات الشخصية (Accounts / Profiles).
    - الإعدادات (Settings / Gear Icon).
- **المرونة:** يدعم النقل إلى شريط العنوان، أو وضعه أعلى الـ SideBar.

---

### (3) الشريط الجانبي الرئيسي `SideBar` (`parts/sidebar/`)

- **الوظيفة:** الحاوية الحركية التي تعرض تفاصيل التبويب النشط في شريط الأنشطة.
- **التصميم الداخلي:**
  - يعتمد على مفهوم `PaneComposite` و `ViewPaneContainer` (`parts/views/`).
  - يقسم المحتوى إلى لوحات قابلة للطي والسحب والترتيب (Collapsible Accordion Panes).
  - على سبيل المثال، في نافذة المستكشف نجد:
    - مجلد المشروع المفتوح (Open Editors).
    - شجرة الملفات (Folders Tree View).
    - المخطط العام للملف الحالي (Outline).
    - المخطط الزمني والتاريخي (Timeline).

---

### (4) مساحة المحرر `EditorPart` (`parts/editor/`)

هي القلب النابض لأي بيئة تطوير؛ وتتميز بتعقيد معماري عالي:

#### أ. إدارة المجموعات (Editor Groups Grid)

- تدعم تقسيم الشاشة إلى شبكة غير محدودة من المجموعات (Split Horizontally / Vertically).
- كل مجموعة (`EditorGroupView`) لها تبويباتها الخاصة ومحررها النشط.

#### ب. رأس المحرر وعناصر التبويب (`EditorTabsControl`)

- يدعم خيارات عرض متعددة:
  - تبويبات متعددة (Multiple Tabs).
  - تبويب واحد (Single Tab).
  - صفوف متعددة للتبويبات (Multi-row Tabs).
  - بدون تبويبات (Breadcrumbs only).
- **حالات التبويب:**
  - معاينة مائلة (Preview Tab - يفتح بنقرة واحدة ويستبدل تلقائياً إذا لم يُعدل).
  - دائم (Pinned Tab).
  - معدل وغير محفوظ (Dirty Indicator `●`).
- **أزرار الأكشن السريعة في زاوية التبويبات:** زر تقسيم الشاشة، زر التشغيل السريع، والقائمة المنبثقة للخيارات.

#### ج. مسار التتبع (Breadcrumbs)

- يقع أسفل التبويبات وفوق كود المحرر مباشرة.
- يعرض مسار الملف: `Project > folder > file.dart > ClassName > functionName`.
- يدعم النقر للانتقال المباشر لأي جزء في الكود.

#### د. سطح التحرير الفعلي (Code Editor Surface)

- يتكون من مساحة الترقيم الجانبية (Gutter/Glyph Margin): أرقام السطور، نقاط التوقف (Breakpoints)، مؤشرات الطي (Folding Controls)، وعلامات تعديلات Git.
- مساحة النصوص (View Lines).
- الخريطة المصغرة للكود (Minimap).
- شريط التمرير المتقدم (Scrollbar مع مؤشرات الأخطاء والبحث).

---

### (5) الشريط الجانبي الإضافي `AuxiliaryBar` (Secondary SideBar)

- إضافة عصرية أصبحت قياسية في بيئات التطوير الحديثة (VS Code, Cursor, Zed).
- **الهدف:** تفريغ الشريط الأيسر وجعل الشريط الأيمن مخصصاً للمحادثة الذكية (AI Agent / Copilot Chat)، أو للمخطط الهيكلي (Outline)، أو الطرفيات الثانوية، دون حجب شجرة الملفات.

---

### (6) اللوحة السفلية `Panel` (`parts/panel/`)

- تقع عادة في الجزء السفلي وتدعم أيضاً نقلها إلى اليمين أو اليسار.
- تعتمد نظام التبويبات الأفقية لعرض أدوات التشغيل:
  - **Terminal:** نافذة الطرفية وسطور الأوامر.
  - **Output:** مخرجات البناء والإضافات.
  - **Problems:** قائمة الأخطاء والتحذيرات اللحظية (Diagnostics).
  - **Debug Console:** شاشة التفاعل مع المترجم أثناء التصحيح.
- تتيح إمكانية التكبير لكامل الشاشة (Maximize Panel) وتغيير الارتفاع بسلاسة.

---

### (7) شريط الحالة `StatusBar` (`parts/statusbar/`)

- شريط أفقي مدمج في أسفل النافذة (ارتفاع 22px).
- **الجهة اليسرى (Operational Info):**
  - الفرع الحالي للـ Git (`git branch`).
  - حالة المزامنة (Sync / Push / Pull).
  - عدد الأخطاء والتحذيرات (`Errors / Warnings count`).
- **الجهة اليمنى (Contextual Editor Info):**
  - رقم السطر والعمود (`Ln 45, Col 12`).
  - المسافات البادئة (`Spaces: 2 / Tab Size: 4`).
  - ترميز الملف (`UTF-8`).
  - نوع فواصل السطور (`CRLF / LF`).
  - اللغة البرمجية المكتشفة (`Dart`, `TypeScript`, `Python`...).
  - مركز الإشعارات (Notification Center Bell).

---

## 3. آليات التفاعل وتغيير المقاسات (Sizing, Splitters & State)

### أ. الفواصل القابلة للسحب (Sash / Resizable Dividers)

بين كل جزء وجزء، توجد منطقة غير مرئية بحجم 4px-8px تُعرف بـ `Sash`:

- تدعم المؤشر الفأري المزدوج (`col-resize` أو `row-resize`).
- تفرض قيود الحجم الأدنى والأقصى:
  - `minimumWidth`: لا يمكن تقليص الشريط الجانبي لأقل من 170px.
  - الإخفاء التلقائي السلس عند سحب الحاجز لنقطة الصفر (`Snap to hide`).

### ب. إدارة الحالة وحفظ أبعاد الواجهة (Layout State & Persistence)

في VS Code، يُستخدم نموذج `LayoutStateKeys` و `IStorageService`:

- تُحفظ كل أبعاد النوافذ (`sideBar.size`, `panel.size`, `auxiliaryBar.size`).
- تُحفظ حالات الظهور (`sideBar.hidden`, `panel.hidden`).
- تُحفظ هذه البيانات على مستويين:
  - **StorageScope.WORKSPACE:** خاصة بمشروع معين (مثل النوافذ المفتوحة وحجم الطرفية لهذا المشروع).
  - **StorageScope.PROFILE:** إعدادات عامة تطبق على مستوى بيئة المطور ككل.

---

## 4. خارطة طريق لتطبيق هذا التصميم في مشروعنا (Flutter Architecture Blueprint)

بما أن مشروعنا مبني على إطار عمل **Flutter**، سنترجم هذه البنية الهندسية إلى معمارية متناسقة مع طبيعة الـ Widgets:

### هيكل الحزم المقترح داخل `lib/`

```text
lib/
├── core/
│   ├── theme/                 # ثيم المحرر (الألوان، الخطوط، المتغيرات)
│   └── constants/             # القياسات والأبعاد القياسية
├── layout/
│   ├── models/                # حالات التخطيط (LayoutState)
│   ├── controllers/           # إدارة حالة فتح/إغلاق اللوحات وتغيير مقاساتها
│   └── widgets/
│       ├── workbench.dart     # الـ Scaffold الأساسي المخصص
│       ├── resizable_box.dart # أداة السحب والتحجيم المشابهة لـ Sash
│       └── custom_splitter.dart
└── parts/
    ├── titlebar/              # شريط العنوان وقوائم النافذة
    ├── activitybar/           # شريط الأيقونات الجانبي
    ├── sidebar/               # مستكشف الملفات والقوائم المنسدلة
    ├── editor/                # منطقة التحرير والتبويبات
    │   ├── tabs/              # شريط التبويبات
    │   ├── breadcrumbs/       # مسار الملف
    │   └── surface/           # سطح النص وأرقام السطور
    ├── auxiliarybar/          # الشريط الجانبي الأيمن (AI / Outline)
    ├── panel/                 # اللوحة السفلية (الطرفية والمخرجات)
    └── statusbar/             # شريط الحالة السفلي
```

### التوصيات التقنية لتطبيق Flutter

1. **استخدام `LayoutBuilder` و `GestureDetector` مخصص:** لمحاكاة حركة الفواصل السلسة بين الأجزاء دون حدوث وميض أو إعادة بناء غير ضرورية (`Rebuilds Optimization`).
2. **استخدام إدارة حالة مركزية وخفيفة (ValueNotifier / BLoC / Riverpod):** لفصل أحداث تغيير الحجم (Resize) عن محتوى النصوص داخل المحرر لضمان 60/120 إطار في الثانية أثناء السحب.
3. **الحفظ التلقائي المحلي (LocalStorage / Shared Preferences):** لحفظ قياسات الأجزاء لتعود كما كانت عند إعادة فتح التطبيق.

---
**الخلاصة:**  
الهيكل التصميمي لـ VS Code يتميز بالفصل الدقيق بين **حاوية التخطيط العامة (Workbench Layout Grid)** وبين **الأجزاء الوظيفية (Parts)** وبين **محتوى العرض (Views & Editors)**، وهو ما يجعل المحرر يدعم أي لغة برمجية عبر تغيير محتوى العرض فقط مع الحفاظ على استقرار وثبات الهيكل المرئي العام.
