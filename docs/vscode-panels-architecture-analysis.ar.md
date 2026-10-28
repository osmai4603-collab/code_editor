# تحليل معماري وتصميم لوحات VS Code: Problems، Output، Debug Console، Terminal

## 1) الخلاصة التنفيذية

لوحات الـ Workbench في VS Code تشترك في نفس الوعاء المعماري — أي نفس مفهوم الـ Panel container والـ tab strip والـ layout shell — لكنها لا تشترك في نفس نموذج البيانات أو نفس فلسفة العرض. هذا هو المفتاح الحقيقي لفهمها.

- Problems هي لوحة بيانات بنيوية: تُبني على مصدر تشخيص واحد، ثم تُجمّع، تُرشّح، وتُنظّم حسب الملف ثم حسب الشدة.
- Output هي لوحة تدفق نصي: ليست بنية دلالية، بل سجل/قناة مخرجات تُعرض كخطوط نصية قابلة للقراءة والتصفية.
- Debug Console هي لوحة تفاعل جلسة التصحيح: ليست مجرد سجل، بل واجهة REPL تفاعلية مع مدخلات/مخرجات/نماذج متداخلة.
- Terminal هي اللوحة الأكثر عمقًا من الناحية المعمارية: ليست مجرد عرض، بل واجهة حية لعملية نظام، تربط بين PTY، xterm.js، وإدارة الجلسات.

الفرق بين هذه اللوحات يثبت قاعدة تصميمية مهمة: "واجهة اللوحة نفسها لا تبرر نفس النموذج الداخلي". كل لوحة تحافظ على طبقتها الخاصة من البيانات، ثم تُرفق داخل نفس حاوية Workbench.

في مشروعنا الحالي، الطابع العام موجود فعليًا في [lib/parts/panel/panel_widget.dart](../lib/parts/panel/panel_widget.dart)، الذي يعرّف شريط تبويبات أسفل المحرر، ويدير تبديل الألواح: Problems، Output، Terminal، Debug Console. هذا يشبه من بعيد بنية VS Code، لكنه لا يزال أقرب إلى "shell workbench" من أن يكون نظامًا كاملًا لكل لوحة.

---

## 2) ما الذي يربط كل اللوحات؟

في VS Code، جميع اللوحات تعتمد على نفس الهيكل العام:

```text
Workbench
└── PanelPart
    └── ViewContainer / Composite
        └── ViewPaneContainer
            └── ViewPane / FilterViewPane
                └── Panel-specific UI
```

هذا يشبه في جوهره تصميم "حاوية + تبويبات + محتوى" لا أكثر. أي أن جميع اللوحات ترث نفس الترتيب المرئي:

- عنوان شريط اللوحة
- تبويبات أو أزرار للتبديل
- مساحة محتوى رئيسية
- أزرار التحكم في الواجهة
- حالة مرئية مثل التوسيع الكامل أو الإخفاء

لكن هذا لا يعني أن كل لوحة لها نفس نوع البيانات. هذا نقطة أساسية في التصميم:

- Problems = قائمة بنيوية ذات هياكل/ملفات/أخطاء
- Output = تدفق نصي متسلسل
- Debug Console = جلسات + REPL + كائنات متداخلة
- Terminal = عملية حية + PTY + I/O مباشر

إذن: التوحيد في الواجهة لا يفرض توحيدًا في النموذج.

في مشروعنا، هذا موجود في [lib/layout/models/layout_state.dart](../lib/layout/models/layout_state.dart)، حيث يتم تحديد حالة العمل العلوية والسفلية والـ PanelTab، ثم تُستخدم في [lib/parts/panel/panel_widget.dart](../lib/parts/panel/panel_widget.dart) لعرض اللوحة النشطة. هذا تصميم صحيح جدًا لأنه فصل بين:

1. حالة الـ workbench
2. حالة كل لوحة
3. واجهة العرض

لكن يجب تطوير كل لوحة بشكل مستقل، لا أن تُعد كل واحدة كنسخة من نفس Widget المكرر.

---

## 3) Problems: تصميم لوحة البيانات لا لوحة logs

### 3.1 التصميم المعماري

Problems في VS Code مبني على فكرة مركزية قوية جدًا:

```text
Marker Source
  (language, task, linter, extension, diagnostics provider)
        ↓
IMarkerService
        ↓
MarkersModel
        ↓
MarkersView / MarkersViewModel
        ↓
Tree/Table rendering + navigation + Quick Fix
```

المفتاح هنا: لا يتم تجميع البيانات داخل عنصر واجهة واحد. بل يوجد مصدر بيانات موحد، ثم نموذج يقسمه حسب URI، ثم واجهة تعرضه. هذا هو نموذج "source of truth" الذي يضمن:

- تحديث موحد لكل مشكلة
- ترشيح متوافق عبر الملفات
- فتح سريع من القائمة إلى الموقع في المحرر
- تكامل مع Quick Fix وnavigation

### 3.2 ما الذي يميّز تصميمه؟

- التنظيم حسب الملف: كل مشكلة تقع تحت ملفها، ثم تحت نوع المشكلة داخل الملف.
- التصنيف حسب الشدة: Error/Warning/Info/Hint
- الفهرسة حسب الموقع: السطر، العمود، المورد، المصدر
- المرشحات: search / errors / warnings / active file / files.exclude
- تفاعل متقدم: open file، jump to location، action context

الاختلاف عن Output كبير: Problems معرفة دلاليًا وليست مجرد نص. هناك معنى لكل عنصر: خطأ، مصدره، حيث يحدث، وكيف يفتح.

### 3.3 التطبيق في مشروعنا

بنية مشروعنا في [lib/parts/panel/views/problems_view.dart](../lib/parts/panel/views/problems_view.dart) تشبه الفكرة الأساسية جدًا:

- تجميع التشخيصات حسب URI
- عرض مجموعة مشاكل لكل ملف داخل ExpansionTile
- تمثيل لكل مشكلة برمز الشدة
- فتح الملف عند النقر
- عرض السطر والعمود

هذا تصميم جيد جدًا ومبني على نفس الفكرة الأساسية لـ VS Code:

```text
DiagnosticsService
        ↓
diagnosticsByUri
        ↓
Grouped UI
```

لكننا نحتاج إلى تطويره أكثر على عدة مستويات:

1. تفكيك البيانات عن العرض: لا تضع الواجهة منطق التجميع بشكل مدمج فقط.
2. دعم التصفية الفعلي: active file / error-only / warning-only / text search.
3. دعم القيم المهيكلة: source، code، related information، severity label.
4. دعم فضاء أقل مرئية: عرض جدول/شجرة حسب الوضع.
5. دعم navigation + action menu + selection state.

### 3.4 الشكل التصميمي المطلوب في مشروعنا

إذا أردنا تصميم Problems في مشروعنا بنفس جودة VS Code، فيجب أن يأخذ هذا الشكل:

```text
ProblemsPanel
├── ProblemsController
│   ├── diagnostics service
│   ├── filter model
│   ├── active file context
│   └── selection state
├── ProblemsTreeModel
│   ├── file group
│   ├── diagnostic items
│   └── sort/order
└── ProblemsRenderer
    ├── tree/list mode
    ├── compact mode
    └── action bar
```

أي أن واجهة Problems لا تكون فقط "قائمة بالأخطاء"، بل طبقة render فوق نموذج كامل.

---

## 4) Output: لوحّة تدفق النص لا لوحة دلالية

### 4.1 الفلسفة المعمارية

Output في VS Code لا يمثل "مشاكل". هو في الأساس وسيلة لعرض تدفق نصي من قنوات متعددة، مثل:

- Output channel للـ extension
- logs من بناء المشروع
- مخرجات تنفيذ المهام
- رسائل نظام

الموديل الأساس هنا ليس شجرة أو ذاكرة تشخيصات، بل سلسلة خطية من السطور في قناة معينة.

```text
IOutputService
  ├── channel registry
  ├── output model
  ├── filter state
  └── scroll/selection support
        ↓
OutputViewPane
        ↓
Monaco read-only editor / text model
```

### 4.2 التصميم الجمالي والوظيفي

- شريط عنوان واضح
- قائمة قنوات في جانب/أعلى
- كل قناة لها محتوى نصي خاص
- التصفية / البحث داخل السجل
- التمرير الذاتي إلى الأسفل عند تزايد البيانات
- عرض نصي سريع وفعال جدًا

هذا يجعلها ممتازة في السيناريوهات التالية:

- سجلات مطور
- تصحيح محلي
- تشغيل أوامر / tasks
- debug logs

### 4.3 تطبيقها في مشروعنا

في مشروعنا، [lib/parts/panel/views/execution_output_view.dart](../lib/parts/panel/views/execution_output_view.dart) يجسد مفهوم Output بوضوح لكنه يقتصر على تنفيذ مبسط جدًا:

- حالة تنفيذ (running/stopped)
- أزرار Run / Stop / Clear
- عرض قائمة من خطوط الإخراج
- التمرير إلى أسفل تلقائي

هذا قريب جدًا من مبدأ Output في VS Code، لأن الأنماط الأساسية متشابهة:

- مصدر رسائل واحد
- قائمة خطوط نصية
- أزرار تحكم
- شريط حالة

لكن الاختلاف الأكبر أن VS Code Output يضيف:

- قنوات متعددة لكل مصدر
- فلاتر/بحث/تنسيق
- تخزين منظم للنص
- تصنيف حسب مستوى stdout/stdin/stderr
- نموذج نصي قابل للتصفية بذكاء

### 4.4 الشكل المطلوب في مشروعنا

لوحة Output في مشروعنا يجب أن تحول إلى هذه البنية:

```text
ExecutionOutputPanel
├── OutputChannelRegistry
├── OutputBuffer
│   ├── stdout
│   ├── stderr
│   ├── system info
│   └── timestamps
├── OutputFilterController
└── Renderer (scrollable text list / editor-like view)
```

هذا يمنحها شكلًا أكثر احترافية ويجعلها قابلة للتوسع إلى logs حقيقية بدل مجرد "ListView للسطر الأخير".

---

## 5) Debug Console: REPL-based panel وليس مجرد log view

### 5.1 المعنى المعماري

Debug Console في VS Code لا ينبغي فهمه كـ Output عادي. هو واجهة REPL تفاعلية مرتبطة بجلسة تصحيح معينة. أي أنها مرتبطة بالـ debug session، وليس فقط بالنص.

```text
Debug Session
        ↓
IDebugService + IDebugSession
        ↓
ReplModel
        ├── input history
        ├── evaluation output
        ├── variables / objects
        ├── console events
        └── session state
        ↓
Repl + Monaco input
```

### 5.2 ما الذي يميّزها؟

- الاتصال بجلسة التصحيح الحالية
- مدخلات تفاعلية للتقييم
- إخراج من نوع expressions، variables، exceptions
- عرض هياكل متداخلة في كائنات/متغيرات
- حالة تتغير حسب الجلسة وقد يكون هناك أكثر من جلسة في نفس الوقت

هذا يضعها في قاعدة مختلفة من Problems وOutput وTerminal: فهي ليست هيكلية كـ Problems، ليست مجرد log كـ Output، وليست process-driven كـ Terminal.

### 5.3 التطبيق في مشروعنا

في مشروعنا، لوحة Debug Console موجودة فقط كـ placeholder في [lib/parts/panel/panel_widget.dart](../lib/parts/panel/panel_widget.dart):

```dart
case PanelTab.debugConsole:
  return Center(
    child: Text('Debug console is ready.'),
  );
```

هذا يدل على أن المشروع يملك مكانًا للوحة، لكن ليس بعد نموذج كامل. هذا هو المجال الذي يحتاج إلى تصميم حقيقي، لأن Debug Console لا يمكن أن تُبنى كنسخة من Output. يجب أن يكون لها:

- جلسة DebugController
- model للـ console entries
- input field
- evaluation pipelines
- structure tree للمتغيرات

### 5.4 الشكل المثالي للـ Debug Console في المشروع

```text
DebugConsolePanel
├── DebugSessionController
├── ReplEntryModel
│   ├── input
│   ├── output
│   ├── error
│   └── value tree
├── VariableTreeRenderer
└── InputLine + Command History
```

هذا يجعلها تشبه VS Code في الفلسفة، وليس فقط في الاسم.

---

## 6) Terminal: اللوحة الأكثر تعقيدًا، والأكثر هشاشة

### 6.1 المعنى المعماري

Terminal في VS Code هو أكثر لوحات الـ panel تعقيدًا لأنّه لا يعتمد فقط على واجهة رسومية؛ بل يعتمد على نظام كامل:

```text
Terminal Service
        ↓
Process / PTY
        ↓
xterm.js / terminal emulator
        ↓
Terminal instance + tabs + split panes
```

أي أن لها ثلاث طبقات في وقت واحد:

1. نظام التشغيل / العملية / PTY
2. الموديل المنطقي لـ terminal sessions
3. واجهة المستخدم التفاعلية

### 6.2 لماذا هو مختلف؟

- لا يسلّم النص فقط، بل يرسل/يستقبل I/O حقيقي
- يتم ربطه بعمليات حية تكتب وتقرأ من stdin/stdout
- له تبويبات، تقسيمات، حالات التشغيل، إعادة الاتصال
- له أذونات وبيئة تشغيل ومزيج من الخيوط والـ sessions

### 6.3 التطبيق في مشروعنا

في مشروعنا، هناك بنية جادة بالفعل في:

- [lib/parts/panel/views/terminal/terminal_panel_view.dart](../lib/parts/panel/views/terminal/terminal_panel_view.dart)
- [lib/parts/panel/views/terminal/terminal_tabbed_view.dart](../lib/parts/panel/views/terminal/terminal_tabbed_view.dart)
- [lib/core/terminal/services/terminal_service.dart](../lib/core/terminal/services/terminal_service.dart)

وهناك أيضًا شريط أزرار في [lib/parts/panel/panel_widget.dart](../lib/parts/panel/panel_widget.dart) لإنشاء terminal جديد، وتغيير حجم اللوحة، وغلقها. هذا يطابق الفكرة الأساسية من VS Code: اللوحة السفلية ليست مجرد قائمة، بل مساحة عمل كاملة.

لكن التنفيذ الحالي ما زال أساسيًا مقارنة بنظام VS Code الكامل. ما ينقصه هو:

- tabs متعددة بعناية
- control panel للـ terminal
- split panes أو متغيرات موحدة
- history/state management
- التفاعل الحقيقي مع shell/PTY

### 6.4 الشكل التصميمي المطلوب

```text
TerminalPanel
├── TerminalService
│   ├── createTerminal
│   ├── disposeTerminal
│   ├── activeTerminal
│   └── terminalRegistry
├── TerminalInstance
│   ├── PTYSession
│   ├── shell environment
│   ├── input/output stream
│   └── exit status
├── TerminalRenderer
│   ├── xterm-like emulator
│   ├── tab bar
│   └── split panes
└── TerminalStatusBar
```

هذا هو الشكل الذي يجعل Terminal ناجحًا من الناحية المعمارية.

---

## 7) مقارنة مباشرة: التصميم المفاهيمي لكل لوحة

| اللوحة | نوع البيانات | أساس التصميم | شكل العرض | النمط المعماري الرئيس |
|---|---|---|---|---|
| Problems | Structured diagnostics | معرفات + ملفات + شدة + موقع | شجرة/جدول | source-of-truth + grouping |
| Output | Streamed text | خطوط نصية + قنوات | قائمة/Editor read-only | log stream |
| Debug Console | Session evaluation | input/output + values + events | REPL + nested object tree | debugger session |
| Terminal | Live process I/O | PTY + shell + session model | Terminal emulator + tabs | process-backed UI |

هذا التمييز مهم جدًا لأنه يحدد أن كل لوحة لا تُفهم كـ "نافذة جاهزة" فقط، بل كـ "نظام معلومات مختلف".

---

## 8) ما الذي يحققه مشروعنا فعليًا؟

في هذا المشروع، بنية اللوحة السفلية موجودة في [lib/parts/panel/panel_widget.dart](../lib/parts/panel/panel_widget.dart) وبها:

- شريط تبويبات للوحات
- حالة التحديد الحالية
- أزرار التحكم: إضافة terminal، تكبير اللوحة، إغلاق اللوحة
- تبديل بين مجموعة من الواجهات

وهذه هي المرحلة الأولى من المحاكاة البصرية لنظام VS Code. وهي مرحلة جيدة جدًا لأنها تنفذ الـ shell workbench بشكل سليم.

الوجوه الحالية في المشروع:

- ProblemsView: تقريب جيد من VS Code في فكرة تجميع التشخيصات
- ExecutionOutputView: تقريب جيد من Output الطابع الإجرائي/التشغيلي
- TerminalPanelView: تقريب صحيح للنظام التبويبي للـ terminal
- Debug Console: لا يزال placeholder وليس نظامًا حقيقيًا

إذن المشروع يملك بالفعل "مخططًا معماريًا" مشابهًا لـ VS Code، لكنه يحتاج إلى التمايز بين اللوحات بدل التوحيد الصوري فقط.

---

## 9) مبدأ التصميم الذي يجب اعتماده في المشروع

إذا أردنا تطبيق VS Code بنفس جودة التصميم، فالأمر لا يكمن في جعل كل لوحة تبدو متشابهة. الأمر يكمن في الحفاظ على هذه المبادئ:

### 9.1 فصّل بين الحالة والواجهة

كل لوحة يجب أن يكون لها:

- State model
- Controller/Service
- Renderer
- Event/input/output pipeline

### 9.2 لا تجعل كل اللوحات قائمة نصية

Problems هي قائمة من الحقول المعقدة، Output هي تدفق سطور، Debug Console هي جلسة REPL، Terminal هو PTY-driven UI.

### 9.3 اعتمد "single source of truth" لكل لوحة

- Problems: DiagnosticsService
- Output: OutputChannelService / OutputBuffer
- Debug Console: DebugSessionService
- Terminal: TerminalService + session registry

### 9.4 حافظ على نفس اللغة البصرية لـ VS Code

- ألوان متدرجة حسب مستوى المشكلة
- رأسية UI خفيفة ومسطحة
- شريط تبويبات رقيق
- أزرار أدوات خفيفة
- مستوى تباين مناسب
- margins وpadding متناسق

### 9.5 اجعل كل لوحة تستجيب لنمطها الخاص

- Problems: grouping/filtering/navigation
- Output: streaming + auto-scroll + search
- Debug Console: nested values + session state + command evaluation
- Terminal: live process interaction + tabs + focus retention

---

## 10) الخلاصة النهائية

لوحات VS Code ليست فقط "أدوات سمينة في أسفل المحرر"؛ بل هي نماذج معمارية كاملة لكل نوع من أنواع المعلومات:

- Problems = نظام تشخيصات
- Output = نظام سجل/قنوات
- Debug Console = نظام REPL مرتبط بالجلسة
- Terminal = نظام عمليات حية

المفتاح في التطبيق في مشروعنا ليس جعل الواجهة متشابهة بصريًا فقط، بل جعل كل جزء من هذه اللوحات يعتمد على نموذج معلوماته الخاص، مع احتفاظه بنفس الحاوية العامة للـ Panel. هذا هو الذي يفصل بين التصميم الجيد وبين مجرد "تبويبات في الأسفل".

من جهة المشروع الحالي، التقدم موجود بالفعل في اتجاه صحيح: شريط اللوحة السفلية، تبويباتها، ومحتوى كل لوحة. لكن المجال الحقيقي الذي يفتح الطريق إلى جودة VS Code هو التمايز المعماري لكل لوحة، لا مجرد التوحيد البصري.

إذا أُعيد تنظيم المشروع وفق هذا المنهج، فسيصبح PanelWidget في المشروع ليس مجرد حاوية عرض، بل واجهة workbench حقيقية ومتكاملة، قادرة على دعم لوحات تشخيصات، مخرجات، تصحيح، وطرفية بشكل احترافي.
