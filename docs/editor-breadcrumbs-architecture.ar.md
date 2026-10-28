# تحليل Breadcrumbs في المحرر

## النطاق

تشرح هذه الوثيقة تنفيذ شريط التنقل Breadcrumbs في نسخة المصدر الموجودة في هذا المشروع: بنيته المرئية، مكوناته، بناء مسار الملف والرموز، دورة التحديث، التفاعل، الإعدادات، وإدارة دورة الحياة. المقصود هو Breadcrumbs الخاصة بمجموعات المحررات في Workbench، لا مسارات التنقل الخاصة بالـ Notebook أو ميزات أخرى تحمل الاسم نفسه.

تتوزع المسؤولية أساسًا بين:

- [breadcrumbs.ts](../src/vs/workbench/browser/parts/editor/breadcrumbs.ts): خدمة تسجيل عناصر الشريط وتعريف إعداداته.
- [breadcrumbsModel.ts](../src/vs/workbench/browser/parts/editor/breadcrumbsModel.ts): تكوين عناصر مسار الملف والرموز.
- [breadcrumbsControl.ts](../src/vs/workbench/browser/parts/editor/breadcrumbsControl.ts): تركيب الواجهة وتحديثها والتعامل مع الاختيار والأوامر.
- [breadcrumbsPicker.ts](../src/vs/workbench/browser/parts/editor/breadcrumbsPicker.ts): قوائم اختيار الملفات والرموز التي تظهر عند فتح عنصر.
- [breadcrumbsWidget.ts](../src/vs/base/browser/ui/breadcrumbs/breadcrumbsWidget.ts): عنصر واجهة عام يعرض عناصر Breadcrumbs ويعالج التركيز والتمرير.
- [breadcrumbscontrol.css](../src/vs/workbench/browser/parts/editor/media/breadcrumbscontrol.css) و[breadcrumbsWidget.css](../src/vs/base/browser/ui/breadcrumbs/breadcrumbsWidget.css): مظهر طبقة Workbench والـ widget العام.
- [editorHeaderControl.ts](../src/vs/workbench/browser/parts/editor/editorHeaderControl.ts) و[singleEditorTabsControl.ts](../src/vs/workbench/browser/parts/editor/singleEditorTabsControl.ts): إنشاء الشريط وموضعه بحسب نمط عنوان المحرر.

## الخلاصة المعمارية

يمكن اختصار تدفق التنفيذ كما يلي:

1. ينشئ عنوان مجموعة المحررات `BreadcrumbsControlFactory`، التي تتأكد من أن Breadcrumbs مفعّلة على مستوى الإعدادات وخيارات جزء المحرر.
2. ينشئ المصنع `BreadcrumbsControl` للمجموعة النشطة، ويسجل الـ widget الخاص بها في `IBreadcrumbsService` كي تصل إليه أوامر لوحة المفاتيح.
3. عند تغير المحرر، يستخرج عنصر التحكم URI مناسبًا للمورد؛ وفي محرر diff يفضّل المورد الأصلي للجهة الأساسية.
4. ينشئ `BreadcrumbsModel` مسار الملف، ثم يطلب من `IOutlineService` مخطط الرموز الخاص بهدف Breadcrumbs.
5. يحول عنصر التحكم عناصر النموذج إلى `FileItem` و`OutlineItem`، ثم يمررها إلى `BreadcrumbsWidget`.
6. يعرض الـ widget العناصر أفقيًا. النقر على عنصر يفتح قائمة الملفات أو الرموز، إلا إذا اختير Quick Pick أو طلب المستخدم إظهار العنصر مباشرة.

الطبقات تفصل بين **مصدر البيانات** (`BreadcrumbsModel` وOutline)، و**سياسة Workbench والتفاعل** (`BreadcrumbsControl`)، و**العرض العام** (`BreadcrumbsWidget`).

## موضع الشريط وبنيته المرئية

يوجد أكثر من شكل للعرض بحسب إعدادات ومخطط عنوان مجموعة المحررات:

- مع أشرطة تبويبات متعددة، ينشئ `EditorHeaderControl` حاوية `breadcrumbs-below-tabs` بعد/ضمن منطقة عنوان المجموعة، ويضع فيها `BreadcrumbsControl`.
- عند عرض Breadcrumbs داخل ترويسة المجموعة، تبقى الترويسة مسؤولة عن إظهارها بالتنسيق مع أفعال المجموعة وإعادة تخطيط مساحة المحرر.
- في نمط التبويب المفرد الذي لا يستخدم ترويسة Breadcrumbs، ينشئ `SingleEditorTabsControl` عنصر التحكم ضمن حاوية عنوان المحرر نفسها. في هذا النمط تكون خلفية الـ widget شفافة، ولا تعرض عناصر المسار أيقونات الملفات، بينما يمكنها عرض أيقونات الرموز.
- منطقة Breadcrumbs ارتفاعها `22px` في تنسيق العنوان العادي. ارتفاع الترويسة نفسها يُدار من `EditorHeaderControl` ويختلف بين الوضع الافتراضي والمضغوط.

العناصر مرتبة من جذر/مجلد إلى ملف، ثم من الرمز الأعلى إلى الرمز الأكثر تحديدًا. الفواصل هي أيقونة Breadcrumb separator، والعنصر الأخير يمثل الموضع الحالي. عند ضيق المساحة لا تلف العناصر إلى سطر آخر؛ يحتفظ الـ widget بصف أفقي واحد ويستخدم التمرير الأفقي. يكشف التمرير العنصر الذي يركز عليه المستخدم أو العنصر الأخير بعد التحديث.

تضيف طبقة Workbench حدًا سفليًا بلون theme token `editorWidget.border`. وعند وجود قائمة نوع المحرر تكون ضمن الطرف الآخر من الشريط، بأيقونة سهم ونص مقتطع، وتحجز عرضها من مساحة الـ widget كي لا يتداخل المحتوى معها. ألوان الخلفية والنص والتركيز تأتي من أنماط Breadcrumbs في الـ theme؛ وعناصر التركيز/التحديد لها تمييز بصري، كما تظهر تسميات العناصر الطويلة مقتطعة بدل تمديد التخطيط.

## المكونات ومسؤولية كل منها

### `BreadcrumbsService`

خدمة بسيطة تحفظ `BreadcrumbsWidget` بحسب معرّف مجموعة المحرر. يسجل `BreadcrumbsControl` الـ widget عند إنشائه ويلغي التسجيل عند التخلص منه. تستعملها أوامر التركيز والتنقل للوصول إلى widget المجموعة النشطة دون ربط الأوامر بتفاصيل DOM.

### `BreadcrumbsConfig`

طبقة ربط صغيرة فوق `IConfigurationService`: توفر قراءة الإعداد، تحديثه، وحدث تغير مخصص به. تستخدمها المكونات للاشتراك في الإعدادات التي تؤثر على عرضها أو نموذجها، مع التخلص من المستمعين عند انتهاء عمر المكون.

### `BreadcrumbsModel`

يمتلك المورد الحالي ويمثل العناصر في قائمة مرتبة من `FileElement` و`OutlineElement2`. كما يتابع تغير مجلدات مساحة العمل، تنسيقات التسميات، ومخطط الرموز في المحرر. يصدر `onDidUpdate` كي يعيد عنصر التحكم بناء عناصر العرض.

### `BreadcrumbsControl`

هو منسق واجهة المجموعة: يبني الـ widget، يربطه بالنموذج، يضبط مفاتيح السياق، يقرر إظهار/إخفاء الشريط، ينشئ الـ pickers، ويترجم أحداث التركيز والاختيار إلى فتح ملف أو كشف رمز. كما ينسق قائمة نوع المحرر الاختيارية ويأخذ إعدادات شريط التمرير من إعدادات عنوان المحرر.

### `BreadcrumbsControlFactory`

ينشئ عنصر التحكم فقط عندما يكون الإعداد `breadcrumbs.enabled` مفعّلًا وخيار `showBreadcrumbs` في `IEditorPartOptions` لا يمنعه. يتابع تغير الإعدادات وخيارات جزء المحرر، ويحدث العنصر عند تغير تسجيل مزود نظام الملفات. فصل المصنع عن عنصر التحكم يسمح بإنشاء العنصر أو التخلص منه بالكامل عند التعطيل.

### عناصر العرض و`BreadcrumbsWidget`

- `FileItem` يرسم الملف أو المجلد باستخدام `ResourceLabel`، مع تسميات وأيقونات الملفات والـ hover حسب خيارات الموضع.
- `OutlineItem` يعيد استخدام renderer/template الخاص بـ Outline كي يطابق الرمز طريقة عرضه في بقية واجهة VS Code. ويمكنه تجهيز السحب والإفلات لرمز المصدر عند السماح بذلك.
- `BreadcrumbsWidget` لا يعرف معنى الملف أو الرمز؛ يستقبل عناصر من نوع `BreadcrumbsItem`، يرسمها ضمن عناصر `role=listitem` داخل قائمة `role=list`، ويدير focus/selection والتمرير وإعادة استخدام العقد DOM.

## كيف يُبنى المسار

### اختيار المورد المدعوم

يستخرج `BreadcrumbsControl.update()` المورد الأساسي للمحرر. في المحررات المركبة مثل diff يؤخذ المورد الأصلي للجهة الأساسية عند توافره، وإلا يستخدم URI القانوني. إذا لم يوجد مورد، أو لم يكن له مزود ملفات (باستثناء `untitled`)، يصبح الشريط غير ممكن ويُخفى.

### مسار الملفات والمجلدات

يبدأ `BreadcrumbsModel` من URI الملف ويصعد عبر `dirname`، ثم يعكس الترتيب ليكون من الأعلى إلى الأسفل. يتوقف الصعود عند جذر مجلد مساحة العمل أو URI الـ home المعرّف بخدمة التسميات أو عند جذر المسار. يصنف العنصر الأخير ملفًا، والعناصر السابقة مجلدات.

- في مساحة عمل متعددة الجذور يُضاف اسم جذر مساحة العمل إلى البداية.
- في مساحة العمل ذات الجذر الواحد يُضاف الجذر عندما يكون المورد نفسه هو ذلك الجذر؛ أما الملفات أسفله فتظهر نسبيًا إليه.
- إذا وفرت خدمة التسميات `home` للمورد، يُعرض المسار من ذلك الموضع، مع تسميات المنزل المخصصة.
- موارد `untitled` و`data` لا تنتج مسار ملف.

يعكس `isRelative()` ما إذا كان المسار مرتبطًا بجذر مساحة العمل أو home، وتستخدمه CSS لاختيار الفاصل/المظهر المناسب.

### مسار الرموز

يطلب النموذج من `IOutlineService` إنشاء Outline باستخدام `OutlineTarget.Breadcrumbs` للمحرر الحالي. تُحوّل عناصر `breadcrumbsDataSource` إلى `OutlineElement2` وتُلحق بعد عناصر الملف. إذا لم يقدم الـ Outline عناصر Breadcrumbs لكنه غير فارغ، يعرض النموذج عنصرًا يمثل الـ Outline نفسه (وتعرضه الواجهة كعلامة `…`).

إنشاء الـ Outline غير متزامن. عند تبدل المحرر أو الـ Outline السابق، تلغى العملية السابقة وتُتخلص النتيجة إن وصلت بعد الإلغاء. يتابع النموذج تغيرات الـ Outline نفسه، ويبلغ عن الأخطاء غير المتوقعة بدل ابتلاعها.

### خيارات الاقتصاص

- `breadcrumbs.filePath`: `on` يعرض المسار، و`off` يخفيه، و`last` يبقي آخر عنصر ملف/مجلد فقط.
- `breadcrumbs.symbolPath`: `on` يعرض التسلسل الكامل للرموز، و`off` يخفي الرموز، و`last` يعرض الرمز الحالي فقط.

## التفاعل والسلوك

### اختيار عنصر

عند النقر، يركز الـ widget العنصر ثم يرسل حدث تحديد مع بيانات الحدث. يفعّل `BreadcrumbsControl` مجموعة المحرر المالكة، ثم يطبق أحد المسارات التالية:

1. **إظهار مباشر**: إذا كانت بيانات الحدث تطلب Reveal، يفتح الملف في المجموعة الحالية أو الجانبية، أو يكشف الرمز داخل المحرر. المجلد لا يفتح كمحرر؛ ينتقل العنصر إلى المجلد التالي في المسار ويعرض محتوياته.
2. **Quick Pick**: إذا كانت قيمة `breadcrumbs.useQuickPick` مفعلة، يفتح Quick Access. تمرر `@` عند اختيار مسار رموز كي ينتقل البحث إلى رموز الملف.
3. **قائمة Breadcrumbs السياقية**: في الوضع الافتراضي، يفتح `BreadcrumbsFilePicker` للمسار أو `BreadcrumbsOutlinePicker` للرمز. وهما شجرتا اختيار أحاديتا التحديد، مرتبطتان بمكان العنصر.

### قائمة الملفات

تستخدم `BreadcrumbsFilePicker` شجرة ملفات غير متزامنة. تبدأ من المجلد الأب أو مساحة العمل عند اختيار الجذر، وتحدد العنصر الحالي وتركز عليه. ترتب المجلدات قبل الملفات، وتطبق `files.exclude` باستخدام إعدادات كل مجلد مساحة عمل، وتراعي حساسية حالة الأحرف لمزود نظام الملفات. لا تنفذ معاينة عند تغيير التركيز. اختيار ملف يفتحه؛ ويمكن فتحه في مجموعة جانبية عند طلب ذلك.

### قائمة الرموز

تستخدم `BreadcrumbsOutlinePicker` بيانات العرض والـ renderers وdatasource التي يوفرها Outline نفسه. تبدأ من Outline الحالي، وتكشف العنصر المحدد وتركز عليه، وتوسع العقد تفاعليًا. عند انتقال التركيز تستدعي `outline.preview()`؛ وعند الاختيار تستدعي `outline.reveal()`. ترتيب عناصر القائمة يتبع `breadcrumbs.symbolSortOrder`.

تُفتح القوائم في Context View أسفل العنصر، مع سهم يشير إلى موضعه، وبحد أقصى ارتفاع محدود بالنافذة/المساحة المتاحة. تُغلق عند فقدان التركيز أو تغير مقياس العرض، ويُستعاد View State لمعاينة الرموز عند إغلاقها من دون اختيار (وكذلك عند اختيار فتح جانبي).

### قائمة نوع المحرر

عندما تسمح خيارات المجموعة بعرضها، ويكون `breadcrumbs.showEditorType` مفعّلًا، ويجد محلل المحررات أكثر من نوع صالح للمورد، يظهر زر باسم المحرر الحالي. النقر عليه يفتح قائمة بأنواع المحررات المتاحة، بما فيها حالات diff. لا تظهر القائمة لمجرد تفعيل الخيار إذا لم يوجد بديل متخصص متاح.

### أوامر لوحة المفاتيح والسياق

تسجل الأوامر في `breadcrumbsControl.ts`، ويقيّد تشغيلها ظهور الشريط أو امتلاكه للتركيز بحسب الحاجة. أهمها:

| الأمر | الاختصار الافتراضي |
| --- | --- |
| `breadcrumbs.toggle` | من لوحة الأوامر/قائمة Appearance؛ يبدل `breadcrumbs.enabled` |
| `breadcrumbs.focusAndSelect` | `Ctrl/Cmd+Shift+.`؛ يركز ويحدد آخر عنصر |
| `breadcrumbs.focus` | `Ctrl/Cmd+Shift+;`؛ يركز آخر عنصر |
| `breadcrumbs.focusNext` / `breadcrumbs.focusPrevious` | الأسهم يمين/يسار أثناء تركيز Breadcrumbs |
| `breadcrumbs.selectFocused` | `Enter` أو `Down`؛ يفتح اختيار العنصر |
| `breadcrumbs.revealFocused` | `Space` أو `Ctrl/Cmd+Enter`؛ يكشف العنصر مباشرة |
| `breadcrumbs.selectEditor` | `Escape`؛ يعيد التركيز إلى المحرر |
| `breadcrumbs.copyPath` | أمر لوحة الأوامر/قائمة سياق عنوان المحرر؛ ينسخ مسار الرموز |

على Mac تختلف بعض بدائل اختصارات الأسهم إلى `Option`. كما توجد قواعد تنقل منفصلة عندما يكون التركيز داخل قائمة Breadcrumbs. يدير عنصر التحكم مفاتيح السياق `breadcrumbsPossible` و`breadcrumbsVisible` و`breadcrumbsActive` و`breadcrumbsHasSymbols` حتى لا تظهر الأوامر في سياق غير صالح.

أمر النسخ ينسخ أسماء الرموز من Outline الحالي فقط، لا مسار الملفات، ويستخدم `breadcrumbs.symbolPathSeparator` (الافتراضي `.`) مع احترام تجاوزات إعدادات اللغة.

## الإعدادات

التعريفات التالية مسجلة ضمن مجموعة Breadcrumb Navigation في `breadcrumbs.ts`:

| الإعداد | الافتراضي | الوظيفة |
| --- | ---: | --- |
| `breadcrumbs.enabled` | `true` | تمكين/تعطيل Breadcrumbs. |
| `breadcrumbs.filePath` | `on` | إظهار مسار الملف كاملًا أو إخفاؤه أو إظهار العنصر الأخير فقط. |
| `breadcrumbs.symbolPath` | `on` | إظهار مسار الرموز كاملًا أو إخفاؤه أو إظهار الرمز الحالي فقط. |
| `breadcrumbs.symbolSortOrder` | `position` | ترتيب قائمة الرموز حسب الموضع أو الاسم أو النوع؛ قابل للتجاوز بحسب اللغة. |
| `breadcrumbs.icons` | `true` | السماح بعرض الأيقونات؛ قد يقيّد موضع العرض نفسه أيقونات الملفات أو الرموز. |
| `breadcrumbs.showEditorType` | `true` | إظهار قائمة نوع المحرر عند وجود محررات بديلة؛ معلّم كإعداد تجريبي. |
| `breadcrumbs.symbolPathSeparator` | `.` | الفاصل المستخدم عند نسخ مسار الرموز؛ قابل للتجاوز بحسب اللغة. |
| `breadcrumbs.showFiles` و`breadcrumbs.showModules` و`breadcrumbs.showNamespaces` و`breadcrumbs.showPackages` و`breadcrumbs.showClasses` و`breadcrumbs.showMethods` و`breadcrumbs.showProperties` و`breadcrumbs.showFields` و`breadcrumbs.showConstructors` و`breadcrumbs.showEnums` و`breadcrumbs.showInterfaces` و`breadcrumbs.showFunctions` و`breadcrumbs.showVariables` و`breadcrumbs.showConstants` و`breadcrumbs.showStrings` و`breadcrumbs.showNumbers` و`breadcrumbs.showBooleans` و`breadcrumbs.showArrays` و`breadcrumbs.showObjects` و`breadcrumbs.showKeys` و`breadcrumbs.showNull` و`breadcrumbs.showEnumMembers` و`breadcrumbs.showStructs` و`breadcrumbs.showEvents` و`breadcrumbs.showOperators` و`breadcrumbs.showTypeParameters` | `true` لكل منها | مرشحات أنواع رموز؛ جميعها قابلة للتجاوز بحسب اللغة. |

كما يستهلك عنصر التحكم `workbench.editor.titleScrollbarSizing` و`workbench.editor.titleScrollbarVisibility` لتكييف شريط التمرير الأفقي، ويستخدم منتقي الملفات `files.exclude`. في الشفرة المفحوصة، يوجد ربط للاسم `breadcrumbs.useQuickPick` ويُقرأ كخيار منطقي عند الاختيار، لكن لم يُعثر على تعريفه ضمن مجموعة الإعدادات المسجلة في `breadcrumbs.ts`؛ لذلك لا ينبغي افتراض قيمة افتراضية مسجلة له من هذا الملف وحده.

## دورة التحديث والتخلص

- تتغير حالة إنشاء عنصر التحكم عند تبديل الإعداد العام أو خيار `showBreadcrumbs` الخاص بمجموعة المحرر.
- عند فتح محرر أو تغير المورد، يعاد إنشاء النموذج وتحديث العناصر. تغيير `breadcrumbs.icons` يعيد بناء عناصر العرض، وتغير مسار الملف/الرموز يبلغ النموذج لإعادة العرض.
- تغير URI أو المجلدات أو تنسيقات التسميات أو الـ Outline يسبب تحديثًا مناسبًا دون إبقاء مستمعي النموذج السابق.
- عند اختفاء العنصر أو تحديثه، تُغلق قائمة الاختيار المفتوحة، وتُلغى عمليات Outline غير المكتملة، وتُزال العناصر/المستمعات والـ DOM والـ context keys التابعة للمجموعة.
- يعيد الـ widget استخدام بادئة العناصر التي لم تتغير، ويتخلص من العناصر المستبدلة؛ وهذا يحافظ على الموارد التي تمتلكها العناصر ويقلل إعادة الرسم.

## الاختبارات المرتبطة

- [breadcrumbModel.test.ts](../src/vs/workbench/test/browser/parts/editor/breadcrumbModel.test.ts): يختبر تكوين مسار الملفات، جذور مساحة العمل، التسميات المنزلية، وهوية URI.
- [breadcrumbsControl.test.ts](../src/vs/workbench/test/browser/parts/editor/breadcrumbsControl.test.ts): يختبر تكامل عنصر التحكم وسلوك القوائم والاختيار والتفاعل.
- [breadcrumbsWidget.ts](../src/vs/base/browser/ui/breadcrumbs/breadcrumbsWidget.ts): هو موضع منطق rendering/focus/scroll العام، ويُفهم سلوكه مع اختبار التحكم.

## خلاصة

Breadcrumbs في المحرر ليست مسارًا نصيًا ثابتًا، بل واجهة تنقل مشتقة من مورد المحرر ومخطط Outline الخاص به. ينسق `BreadcrumbsModel` مصادر البيانات، بينما يترجم `BreadcrumbsControl` الاختيار إلى تنقل أو فتح قائمة مناسبة، ويظل `BreadcrumbsWidget` طبقة عرض عامة تتولى التركيز والتمرير. يسمح هذا الفصل بتكييف المظهر مع أنماط عناوين المحرر، ودعم الملفات والرموز ومحررات diff وأنواع المحررات البديلة، مع إبقاء دورة الحياة مرتبطة بكل مجموعة محرر على حدة.
