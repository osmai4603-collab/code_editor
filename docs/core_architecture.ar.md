# معمارية نواة المحرر

تحتوي `lib/core` على خدمات ومنطق المحرر المستقل عن واجهة المستخدم. تعتمد النواة
على عقود صغيرة، بينما توفر طبقات التطبيق التنفيذ الذي يحتاج إلى أنواع الواجهة.

## حدود الاعتماد

- لا تستورد ملفات `core` من `layout` أو `features`.
- عند حاجة النواة إلى سلوك يقدمه التطبيق، عرّف عقدًا في `core` ومرّر تنفيذه عبر
  المُنشئ أو استخدم محولًا في الطبقة الأعلى.
- يراجع اختبار `test/architecture/core_layer_imports_test.dart` هذه الحدود.

## التسجيل والتمديد

- سجّل `LanguageDefinition` في `LanguageRegistry` لربط المعرّف والامتدادات
  والملفات الخاصة وقدرات LSP والتنفيذ والمسافات البادئة.
- أضف `ICommandResolver` إلى `CompositeCommandResolver` لتوسيع أنواع الملفات
  القابلة للتشغيل دون تعديل `ExecutionController`.
- أضف `ILspDescriptorSource` و`ILspChannelFactory` لتوفير واصفات خوادم أو وسيلة
  نقل جديدة دون ربط سجل الخوادم بعملية نظام بعينها.
- يمكن حقن `IProcessRunner` و`IGitStatusService` و`IExplorerPersistenceStore`
  في المتحكمات لعزل العمليات والتخزين في الاختبارات.
- `FileExplorerController` واجهة متوافقة للـ UI، وتفوض تنسيق العمل إلى
  `FileExplorerCoordinator`؛ وتعزل خدمات Git والبحث والتخزين والفرز كل مسؤولية
  عن التنسيق نفسه. تتولى `ExplorerFileOperations` عمليات الملفات، ويمتلك
  `ExplorerSelectionState` حالة التحديد والحافظة وتحرير العناصر.

## المحرر والطرفية

- تقبل `EditorInputFormatter` قواعد `LanguageIndentationRules`، مع قواعد افتراضية
  لـ Python وقواعد الأقواس لبقية اللغات.
- يصرّح `PtyBackend.supportsResize` بوضوح؛ لا تستدعِ `resize` إلا عندما يدعمها
  التنفيذ. محول العملية الحالي لا يوفر تغيير الحجم الفعلي.
- تُحفظ خيارات التنسيق عبر `EditorFormattingPreferencesStore`، ويجب الإبلاغ عن
  أخطاء القراءة أو الكتابة بدل تحويلها إلى نجاح صامت.
