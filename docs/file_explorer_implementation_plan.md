# خطة تنفيذية شاملة: نظام File Explorer

> **مبنية على:** [تحليل معمارية File Explorer في VS Code](file:///home/osm/flutter_projects/code_editor/docs/vscode_file_explorer_architecture.md)
> **المشروع المستهدف:** Flutter Code Editor

---

## الوضع الحالي للمشروع

### ما هو موجود حالياً

- [sidebar_widget.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/sidebar/sidebar_widget.dart) — شجرة ملفات ثابتة (hardcoded) بدون قراءة حقيقية من نظام الملفات
- [editor_controller.dart](file:///home/osm/flutter_projects/code_editor/lib/layout/controllers/editor_controller.dart) — `EditorDocumentsController` لإدارة التبويبات
- [editor_tab_item.dart](file:///home/osm/flutter_projects/code_editor/lib/models/editor_tab_item.dart) — نموذج `EditorTabItem` بسيط

### ما ينقص

- ❌ قراءة نظام الملفات الحقيقي (`dart:io`)
- ❌ نموذج بيانات شجري (`FileSystemItem`)
- ❌ خدمة إدارة الملفات (`FileExplorerService`)
- ❌ تحميل كسول للمجلدات (Lazy Loading)
- ❌ فلترة وترتيب
- ❌ عمليات CRUD (إنشاء / حذف / إعادة تسمية / نقل)
- ❌ سحب وإفلات
- ❌ مراقبة تغييرات الملفات (File Watcher)
- ❌ أيقونات ملفات ديناميكية

---

## الهيكل المستهدف للملفات

```text
lib/
├── core/
│   └── file_system/                          ← المرحلة 1-2
│       ├── models/
│       │   ├── file_tree_item.dart            ← نموذج عنصر الشجرة
│       │   ├── file_tree_item_type.dart       ← أنواع العناصر
│       │   └── sort_config.dart              ← إعدادات الترتيب
│       ├── services/
│       │   ├── file_system_service.dart       ← خدمة نظام الملفات
│       │   ├── file_watcher_service.dart      ← مراقب التغييرات
│       │   └── file_icon_resolver.dart        ← حل أيقونات الملفات
│       └── controllers/
│           └── file_explorer_controller.dart  ← وحدة التحكم الرئيسية
│
├── parts/
│   └── sidebar/
│       ├── sidebar_widget.dart                ← تحديث (موجود)
│       └── explorer/                          ← المرحلة 3-5
│           ├── explorer_view.dart             ← العرض الرئيسي
│           ├── explorer_tree.dart             ← شجرة الملفات التفاعلية
│           ├── widgets/
│           │   ├── file_tree_tile.dart         ← عنصر الشجرة
│           │   ├── file_icon_widget.dart       ← أيقونة الملف
│           │   ├── inline_rename_field.dart    ← حقل إعادة التسمية
│           │   ├── section_header.dart         ← رأس القسم
│           │   └── open_editors_list.dart      ← قائمة المحررات المفتوحة
│           └── dialogs/
│               ├── new_file_dialog.dart        ← حوار ملف جديد
│               ├── delete_confirm_dialog.dart  ← تأكيد الحذف
│               └── move_conflict_dialog.dart   ← تعارض النقل
```

---

## المراحل التنفيذية

---

## المرحلة 1: نموذج البيانات وخدمة نظام الملفات

**المدة المقدرة:** 1-2 جلسات | **الأولوية:** 🔴 حرجة

### الهدف

بناء طبقة البيانات الأساسية التي تقرأ نظام الملفات الحقيقي وتمثله كشجرة.

### 1.1 نموذج عنصر الشجرة — `FileTreeItem`

**الملف:** `lib/core/file_system/models/file_tree_item.dart`

```dart
/// يُمثل عنصراً واحداً في شجرة الملفات (ملف أو مجلد)
/// مستوحى من ExplorerItem في VS Code
class FileTreeItem {
  final String name;
  final String path;           // المسار الكامل
  final bool isDirectory;
  final bool isSymbolicLink;
  final bool isHidden;         // يبدأ بنقطة
  final DateTime? modifiedAt;
  final int? sizeBytes;

  FileTreeItem? parent;
  List<FileTreeItem>? _children;  // null = لم يُحل بعد
  
  bool get isResolved => !isDirectory || _children != null;
  bool get isRoot => parent == null;
  
  List<FileTreeItem> get children => _children ?? [];
  set children(List<FileTreeItem> value) { _children = value; }
  
  // البحث في الشجرة
  FileTreeItem? find(String targetPath);
  
  // العمق في الشجرة
  int get depth;
  
  // الحصول على المسار النسبي من الجذر
  String get relativePath;
  
  // الامتداد
  String get extension;
}
```

**ملاحظات التنفيذ:**

- `_children = null` يعني أن المجلد لم يُحمَّل بعد (التحميل الكسول)
- `parent` يُمكّن التنقل لأعلى في الشجرة
- `find()` يبحث بعمق في كل الأبناء المُحلَّلة

### 1.2 إعدادات الترتيب — `SortConfig`

**الملف:** `lib/core/file_system/models/sort_config.dart`

```dart
enum SortOrder { name, type, modified, size }
enum SortDirection { ascending, descending }
enum FolderPosition { first, last, mixed }

class SortConfig {
  final SortOrder order;
  final SortDirection direction;
  final FolderPosition folderPosition;
  final bool caseSensitive;
  
  const SortConfig.defaultConfig();
}
```

### 1.3 خدمة نظام الملفات — `FileSystemService`

**الملف:** `lib/core/file_system/services/file_system_service.dart`

```dart
/// خدمة القراءة/الكتابة لنظام الملفات الحقيقي
/// تغلف dart:io وتوفر واجهة نظيفة
class FileSystemService {
  // --- القراءة ---
  
  /// قراءة محتويات مجلد (مستوى واحد)
  Future<List<FileTreeItem>> listDirectory(String path);
  
  /// قراءة محتوى ملف نصي
  Future<String> readFileContent(String path);
  
  /// فحص وجود ملف/مجلد
  Future<bool> exists(String path);
  
  /// الحصول على معلومات ملف (stat)
  Future<FileStat> stat(String path);
  
  // --- الكتابة ---
  
  /// إنشاء ملف جديد
  Future<FileTreeItem> createFile(String path, {String content = ''});
  
  /// إنشاء مجلد جديد
  Future<FileTreeItem> createDirectory(String path);
  
  /// حذف ملف أو مجلد
  Future<void> delete(String path, {bool recursive = false});
  
  /// إعادة تسمية
  Future<FileTreeItem> rename(String oldPath, String newName);
  
  /// نقل
  Future<FileTreeItem> move(String sourcePath, String targetDirectory);
  
  /// نسخ
  Future<FileTreeItem> copy(String sourcePath, String targetDirectory);
  
  // --- مساعدة ---
  
  /// تحديد اللغة من الامتداد
  String resolveLanguageId(String filename);
}
```

**ملاحظات التنفيذ:**

- تستخدم `dart:io` (`File`, `Directory`, `FileSystemEntity`)
- كل عملية تُعيد `FileTreeItem` محدَّث
- `listDirectory` يقرأ مستوى واحد فقط (كسول)
- معالجة أخطاء شاملة (`FileSystemException`)

### 1.4 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 1.1 | إنشاء `FileTreeItem` | `models/file_tree_item.dart` | — |
| 1.2 | إنشاء `SortConfig` | `models/sort_config.dart` | — |
| 1.3 | إنشاء `FileSystemService` - عمليات القراءة | `services/file_system_service.dart` | 1.1 |
| 1.4 | إنشاء `FileSystemService` - عمليات الكتابة | `services/file_system_service.dart` | 1.3 |
| 1.5 | إنشاء `resolveLanguageId` | `services/file_system_service.dart` | — |
| 1.6 | كتابة اختبارات وحدة | `test/file_system/` | 1.1-1.5 |

### معيار الاكتمال ✅

- [x] `FileTreeItem` يمكنه تمثيل شجرة ملفات كاملة
- [x] `FileSystemService.listDirectory()` يقرأ مجلد حقيقي
- [x] `FileSystemService.readFileContent()` يقرأ ملف حقيقي
- [x] عمليات CRUD تعمل على نظام الملفات الحقيقي
- [x] معالجة أخطاء لمسارات غير موجودة وأذونات مرفوضة

---

## المرحلة 2: وحدة التحكم ومراقب الملفات

**المدة المقدرة:** 1-2 جلسات | **الأولوية:** 🔴 حرجة

### الهدف

بناء وحدة التحكم الرئيسية التي تدير حالة الشجرة + مراقب تغييرات الملفات.

### 2.1 وحدة التحكم — `FileExplorerController`

**الملف:** `lib/core/file_system/controllers/file_explorer_controller.dart`

```dart
/// وحدة التحكم الرئيسية لـ File Explorer
/// مستوحاة من ExplorerService + ExplorerModel في VS Code
class FileExplorerController extends ChangeNotifier {
  final FileSystemService _fileService;
  final FileWatcherService _watcherService;
  
  // --- الحالة ---
  FileTreeItem? _root;              // جذر المشروع
  String? _workspacePath;           // مسار مجلد العمل
  Set<String> _expandedPaths = {};  // المجلدات المفتوحة
  String? _selectedPath;            // العنصر المحدد
  Set<String> _multiSelection = {}; // اختيار متعدد
  SortConfig _sortConfig = const SortConfig.defaultConfig();
  bool _isLoading = false;
  String? _error;
  
  // --- التحرير ---
  String? _editingPath;             // المسار قيد التحرير (rename)
  String? _creatingInPath;          // المجلد الذي يُنشأ فيه عنصر جديد
  bool _creatingIsDirectory = false;
  
  // --- Getters ---
  FileTreeItem? get root => _root;
  String? get workspacePath => _workspacePath;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SortConfig get sortConfig => _sortConfig;
  
  // --- فتح مجلد عمل ---
  Future<void> openWorkspace(String path);
  
  // --- التنقل ---
  Future<void> toggleExpand(FileTreeItem item);
  Future<void> expandTo(String path);    // فتح كل الآباء
  void collapseAll();
  void select(FileTreeItem item);
  void multiSelect(FileTreeItem item);
  bool isExpanded(FileTreeItem item);
  bool isSelected(FileTreeItem item);
  
  // --- عمليات CRUD ---
  Future<void> createFile(String parentPath, String name);
  Future<void> createDirectory(String parentPath, String name);
  Future<void> delete(List<String> paths);
  Future<void> rename(String path, String newName);
  Future<void> move(List<String> sourcePaths, String targetDir);
  Future<void> copy(List<String> sourcePaths, String targetDir);
  
  // --- التحرير المباشر (Inline Editing) ---
  void startRename(String path);
  void startCreate(String parentPath, {bool isDirectory = false});
  void cancelEdit();
  bool isEditing(String path);
  
  // --- الترتيب ---
  void updateSortConfig(SortConfig config);
  
  // --- التحديث ---
  Future<void> refresh({String? path});
  
  // --- البحث ---
  FileTreeItem? findItem(String path);
  
  // --- مراقبة التغييرات ---
  void _onFileChanged(FileChangeEvent event);
  
  // --- مساعدة ---
  List<FileTreeItem> getVisibleItems();  // القائمة المسطحة للعرض
}
```

**تفاصيل `getVisibleItems()`:**

```dart
/// يحول الشجرة إلى قائمة مسطحة للعرض
/// يأخذ بالاعتبار: التوسيع، الترتيب، الفلترة
List<FileTreeItem> getVisibleItems() {
  if (_root == null) return [];
  
  final result = <FileTreeItem>[];
  void walk(FileTreeItem item, int depth) {
    result.add(item);
    if (item.isDirectory && isExpanded(item) && item.isResolved) {
      final sorted = _sortChildren(item.children);
      for (final child in sorted) {
        walk(child, depth + 1);
      }
    }
  }
  
  // إذا كان الجذر مجلد واحد → ابدأ من أبنائه
  final sorted = _sortChildren(_root!.children);
  for (final child in sorted) {
    walk(child, 0);
  }
  
  return result;
}
```

### 2.2 مراقب تغييرات الملفات — `FileWatcherService`

**الملف:** `lib/core/file_system/services/file_watcher_service.dart`

```dart
enum FileChangeType { created, modified, deleted }

class FileChangeEvent {
  final String path;
  final FileChangeType type;
  final DateTime timestamp;
}

/// يراقب تغييرات نظام الملفات ويُبلّغ عنها
/// مستوحى من onDidFilesChange + RunOnceScheduler في VS Code
class FileWatcherService {
  StreamSubscription? _subscription;
  Timer? _debounceTimer;
  final List<FileChangeEvent> _pendingEvents = [];
  
  final _controller = StreamController<List<FileChangeEvent>>.broadcast();
  Stream<List<FileChangeEvent>> get changes => _controller.stream;
  
  /// بدء مراقبة مجلد
  void watch(String directoryPath);
  
  /// إيقاف المراقبة
  void stop();
  
  /// معالجة التغييرات بتجميع (debounce)
  /// يجمع التغييرات لمدة 500ms ثم يُرسلها دفعة واحدة
  void _onRawEvent(FileSystemEvent event);
  
  void dispose();
}
```

**ملاحظات التنفيذ:**

- يستخدم `Directory.watch(recursive: true)` من `dart:io`
- يُجمّع الأحداث بتأخير 500ms (مثل VS Code: `EXPLORER_FILE_CHANGES_REACT_DELAY`)
- يُصفّي الأحداث المكررة والمتناقضة
- يتجاهل `.git/`, `build/`, `.dart_tool/`

### 2.3 تسجيل الخدمات في التطبيق

**تحديث:** `lib/main.dart`

```dart
// إضافة في _CodeEditorAppState.initState():
late final FileSystemService _fileSystemService;
late final FileWatcherService _fileWatcherService;
late final FileExplorerController _explorerController;

@override
void initState() {
  super.initState();
  _fileSystemService = FileSystemService();
  _fileWatcherService = FileWatcherService();
  _explorerController = FileExplorerController(
    fileService: _fileSystemService,
    watcherService: _fileWatcherService,
  );
  // ... باقي التهيئة
}

// إضافة في build():
FileExplorerScope(
  notifier: _explorerController,
  child: /* ... باقي الشجرة ... */
)
```

### 2.4 InheritedNotifier Scope

**الملف:** `lib/core/file_system/controllers/file_explorer_controller.dart` (أسفل الملف)

```dart
class FileExplorerScope extends InheritedNotifier<FileExplorerController> {
  const FileExplorerScope({
    super.key,
    required FileExplorerController super.notifier,
    required super.child,
  });

  static FileExplorerController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FileExplorerScope>()!
        .notifier!;
  }
}
```

### 2.5 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 2.1 | إنشاء `FileWatcherService` | `services/file_watcher_service.dart` | — |
| 2.2 | إنشاء `FileExplorerController` - الحالة الأساسية | `controllers/file_explorer_controller.dart` | 1.1-1.4, 2.1 |
| 2.3 | تنفيذ `openWorkspace()` + `toggleExpand()` | `controllers/file_explorer_controller.dart` | 2.2 |
| 2.4 | تنفيذ `getVisibleItems()` + الترتيب | `controllers/file_explorer_controller.dart` | 2.2 |
| 2.5 | تنفيذ عمليات CRUD في الـ Controller | `controllers/file_explorer_controller.dart` | 2.2 |
| 2.6 | تنفيذ `_onFileChanged()` (ربط المراقب) | `controllers/file_explorer_controller.dart` | 2.1, 2.2 |
| 2.7 | إنشاء `FileExplorerScope` | `controllers/file_explorer_controller.dart` | 2.2 |
| 2.8 | تسجيل الخدمات في `main.dart` | `main.dart` | 2.2, 2.7 |

### معيار الاكتمال ✅

- [x] `openWorkspace()` يقرأ مجلد حقيقي ويبني الشجرة
- [x] `toggleExpand()` يُحمّل المجلدات كسولياً
- [x] `getVisibleItems()` يُعيد قائمة مسطحة مرتبة
- [x] `FileWatcherService` يكتشف الملفات المضافة/المحذوفة/المعدلة
- [x] الـ Controller يُحدّث الشجرة تلقائياً عند تغيير الملفات
- [x] `FileExplorerScope` متاح في شجرة الـ Widget

---

## المرحلة 3: واجهة العرض الأساسية (Explorer View)

**المدة المقدرة:** 2-3 جلسات | **الأولوية:** 🔴 حرجة

### الهدف

بناء واجهة المستخدم التي تعرض شجرة الملفات الحقيقية مع تصميم يُطابق VS Code.

### 3.1 أيقونات الملفات — `FileIconResolver`

**الملف:** `lib/core/file_system/services/file_icon_resolver.dart`

```dart
/// يحدد أيقونة ولون الملف/المجلد بناءً على الاسم والامتداد
/// مستوحى من Seti Icon Theme في VS Code
class FileIconResolver {
  /// أيقونة ملف
  static ({IconData icon, Color color}) resolveFileIcon(String filename);
  
  /// أيقونة مجلد (مفتوح/مغلق)
  static ({IconData icon, Color color}) resolveFolderIcon(
    String folderName, {
    bool isExpanded = false,
  });
  
  // خرائط داخلية:
  // - امتدادات (.dart, .yaml, .json, .md, .py, ...)
  // - أسماء خاصة (Dockerfile, Makefile, .gitignore, ...)
  // - مجلدات خاصة (lib, test, .git, build, ...)
}
```

### 3.2 عنصر الشجرة — `FileTreeTile`

**الملف:** `lib/parts/sidebar/explorer/widgets/file_tree_tile.dart`

```dart
/// عنصر واحد في شجرة الملفات
/// ارتفاع ثابت: 22px (مطابق لـ VS Code)
class FileTreeTile extends StatelessWidget {
  final FileTreeItem item;
  final int depth;           // عمق التداخل
  final bool isSelected;
  final bool isExpanded;     // للمجلدات
  final bool isCut;          // مقصوص (opacity 0.5)
  final bool isEditing;      // وضع إعادة التسمية
  
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleExpand;
  final Function(String)? onRenameSubmit;
  final VoidCallback? onRenameCancelled;
  
  // التصميم المستهدف (22px لكل عنصر):
  //
  // ┌──────────────────────────────────────────────┐
  // │ [indent] [▶/▼] [icon] [name............] │ 22px
  // └──────────────────────────────────────────────┘
  //
  // indent: depth × 16px
  // twistie: 16px (سهم التوسيع، فقط للمجلدات)
  // icon: 16px (أيقونة الملف/المجلد)
  // name: باقي المساحة (ellipsis عند الطول الزائد)
}
```

**قيم CSS الأساسية (من تحليل VS Code):**

| العنصر | القيمة |
| -------- | -------- |
| ارتفاع الصف | `22px` |
| مسافة بادئة لكل مستوى | `16px` (قابل للتعديل: `workbench.tree.indent`) |
| حجم سهم التوسيع | `14px` |
| حجم أيقونة الملف | `16px` |
| حجم خط الاسم | `12.5px` |
| لون الاسم | `theme.sideBarForeground` |
| لون الخلفية عند التحديد | `theme.listActiveSelectionBackground` |
| شفافية العنصر المقصوص | `0.5` |

### 3.3 حقل إعادة التسمية المباشر — `InlineRenameField`

**الملف:** `lib/parts/sidebar/explorer/widgets/inline_rename_field.dart`

```dart
/// حقل إدخال يظهر مكان اسم الملف عند إعادة التسمية
/// مستوحى من renderInputBox في FilesRenderer
class InlineRenameField extends StatefulWidget {
  final String initialName;
  final Function(String) onSubmit;
  final VoidCallback onCancel;
  
  // السلوك:
  // 1. يظهر مع تحديد الاسم بدون الامتداد
  // 2. Enter → onSubmit
  // 3. Escape → onCancel
  // 4. فقدان التركيز → onSubmit (إذا تغير الاسم)
  // 5. حدود: outline بلون focusBorder
}
```

### 3.4 شجرة الملفات — `ExplorerTree`

**الملف:** `lib/parts/sidebar/explorer/explorer_tree.dart`

```dart
/// شجرة الملفات الرئيسية
/// تستخدم ListView.builder للأداء (Virtual List مثل VS Code)
class ExplorerTree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = FileExplorerScope.of(context);
    final items = controller.getVisibleItems();
    
    return ListView.builder(
      itemCount: items.length,
      itemExtent: 22.0,  // ارتفاع ثابت = أداء أفضل
      itemBuilder: (context, index) {
        final item = items[index];
        return FileTreeTile(
          item: item,
          depth: item.depth,
          isSelected: controller.isSelected(item),
          isExpanded: controller.isExpanded(item),
          isEditing: controller.isEditing(item.path),
          onTap: () => _handleTap(context, item),
          onDoubleTap: () => _handleDoubleTap(context, item),
          onToggleExpand: item.isDirectory 
            ? () => controller.toggleExpand(item)
            : null,
        );
      },
    );
  }
  
  void _handleTap(BuildContext context, FileTreeItem item) {
    final explorerCtrl = FileExplorerScope.of(context);
    explorerCtrl.select(item);
    
    if (!item.isDirectory) {
      // فتح الملف في وضع Preview (مثل VS Code: click واحد)
      final editorCtrl = EditorDocumentsScope.of(context);
      _openFileInEditor(editorCtrl, item, isPreview: true);
    }
  }
  
  void _handleDoubleTap(BuildContext context, FileTreeItem item) {
    if (!item.isDirectory) {
      // فتح الملف وتثبيته (مثل VS Code: double click)
      final editorCtrl = EditorDocumentsScope.of(context);
      _openFileInEditor(editorCtrl, item, isPreview: false);
    }
  }
}
```

### 3.5 رأس القسم — `SectionHeader`

**الملف:** `lib/parts/sidebar/explorer/widgets/section_header.dart`

```dart
/// رأس قسم قابل للطي (OPEN EDITORS, PROJECT_NAME)
/// مع أزرار إجراءات (New File, New Folder, Refresh, Collapse All)
class SectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<HeaderAction>? actions;
  
  // التصميم:
  // ┌──────────────────────────────────────────────────────────┐
  // │ [▶/▼] [TITLE]                    [📄] [📁] [🔄] [⊟] │ 24px
  // └──────────────────────────────────────────────────────────┘
}

class HeaderAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}
```

### 3.6 قائمة المحررات المفتوحة — `OpenEditorsList`

**الملف:** `lib/parts/sidebar/explorer/widgets/open_editors_list.dart`

```dart
/// قائمة الملفات المفتوحة حالياً في المحرر
/// مستوحاة من OpenEditorsView في VS Code
class OpenEditorsList extends StatelessWidget {
  // يعرض tabs من EditorDocumentsController
  // لكل عنصر:
  //   - أيقونة dirty (نقطة) أو زر إغلاق (×)
  //   - أيقونة الملف
  //   - اسم الملف
  //   - hover → يظهر زر الإغلاق بدل النقطة
}
```

### 3.7 العرض الرئيسي — `ExplorerView`

**الملف:** `lib/parts/sidebar/explorer/explorer_view.dart`

```dart
/// العرض الرئيسي للمستكشف (يجمع كل المكونات)
class ExplorerView extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // قسم المحررات المفتوحة (قابل للطي)
        SectionHeader(title: 'OPEN EDITORS', ...),
        if (_isOpenEditorsExpanded)
          OpenEditorsList(),
        
        // قسم شجرة الملفات (قابل للطي)
        SectionHeader(
          title: workspaceName.toUpperCase(),
          actions: [
            HeaderAction(icon: Icons.note_add, tooltip: 'New File', ...),
            HeaderAction(icon: Icons.create_new_folder, tooltip: 'New Folder', ...),
            HeaderAction(icon: Icons.refresh, tooltip: 'Refresh', ...),
            HeaderAction(icon: Icons.unfold_less, tooltip: 'Collapse All', ...),
          ],
        ),
        if (_isWorkspaceExpanded)
          Expanded(child: ExplorerTree()),
      ],
    );
  }
}
```

### 3.8 تحديث `SideBarWidget`

تحديث [sidebar_widget.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/sidebar/sidebar_widget.dart) لاستخدام `ExplorerView` بدل الشجرة الثابتة:

```dart
// في _buildActivityContent:
if (activity == ActivityBarItem.explorer) {
  return const ExplorerView();  // ← بدل الشجرة الثابتة القديمة
}
```

### 3.9 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 3.1 | إنشاء `FileIconResolver` | `services/file_icon_resolver.dart` | — |
| 3.2 | إنشاء `FileTreeTile` | `widgets/file_tree_tile.dart` | 1.1, 3.1 |
| 3.3 | إنشاء `InlineRenameField` | `widgets/inline_rename_field.dart` | — |
| 3.4 | إنشاء `SectionHeader` | `widgets/section_header.dart` | — |
| 3.5 | إنشاء `OpenEditorsList` | `widgets/open_editors_list.dart` | — |
| 3.6 | إنشاء `ExplorerTree` | `explorer_tree.dart` | 3.2, 2.2 |
| 3.7 | إنشاء `ExplorerView` | `explorer_view.dart` | 3.4-3.6 |
| 3.8 | تحديث `SideBarWidget` | `sidebar_widget.dart` | 3.7 |
| 3.9 | ربط فتح الملفات مع `EditorDocumentsController` | `explorer_tree.dart` | 3.6 |

### معيار الاكتمال ✅

- [x] شجرة الملفات تعرض محتويات مجلد حقيقي
- [x] المجلدات تتوسع/تنطوي بالنقر
- [x] التحميل الكسول يعمل (لا يُقرأ المجلد حتى يُفتح)
- [x] النقر على ملف يفتحه في المحرر (preview)
- [x] النقر المزدوج يفتحه ويثبته (pin)
- [x] أيقونات ملفات ديناميكية حسب الامتداد
- [x] `ListView.builder` مع `itemExtent: 22` للأداء
- [x] قسم Open Editors يعرض التبويبات المفتوحة

---

## المرحلة 4: عمليات الملفات وقائمة السياق

**المدة المقدرة:** 1-2 جلسات | **الأولوية:** 🟡 مهمة

### الهدف

إضافة عمليات CRUD مع قائمة سياق (Right-click menu) وإعادة تسمية مباشرة.

### 4.1 قائمة السياق — Context Menu

```dart
/// قائمة سياق عند النقر بالزر الأيمن على عنصر في الشجرة
void _showContextMenu(BuildContext context, FileTreeItem item, Offset position) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, ...),
    items: [
      // --- مجموعة التنقل ---
      if (item.isDirectory) ...[
        PopupMenuItem('New File', onTap: () => _createFile(item)),
        PopupMenuItem('New Folder', onTap: () => _createFolder(item)),
        PopupMenuDivider(),
      ],
      
      // --- مجموعة التحرير ---
      PopupMenuItem('Cut', shortcut: 'Ctrl+X'),
      PopupMenuItem('Copy', shortcut: 'Ctrl+C'),
      PopupMenuItem('Paste', shortcut: 'Ctrl+V'),
      PopupMenuDivider(),
      
      // --- مجموعة الإدارة ---
      PopupMenuItem('Copy Path', shortcut: 'Shift+Alt+C'),
      PopupMenuItem('Copy Relative Path', shortcut: 'Ctrl+Shift+C'),
      PopupMenuDivider(),
      PopupMenuItem('Rename', shortcut: 'F2'),
      PopupMenuItem('Delete', shortcut: 'Delete'),
      PopupMenuDivider(),
      
      // --- مجموعة العرض ---
      if (item.isDirectory)
        PopupMenuItem('Reveal in File Manager'),
      PopupMenuItem('Open in Terminal'),
    ],
  );
}
```

### 4.2 عمليات الحافظة (Cut/Copy/Paste)

```dart
// في FileExplorerController:
List<String>? _clipboardPaths;
bool _clipboardIsCut = false;

void cut(List<String> paths) {
  _clipboardPaths = paths;
  _clipboardIsCut = true;
  notifyListeners();  // لعرض opacity 0.5
}

void copy(List<String> paths) {
  _clipboardPaths = paths;
  _clipboardIsCut = false;
  notifyListeners();
}

Future<void> paste(String targetDir) async {
  if (_clipboardPaths == null) return;
  
  if (_clipboardIsCut) {
    await move(_clipboardPaths!, targetDir);
    _clipboardPaths = null;
  } else {
    await copy(_clipboardPaths!, targetDir);
  }
  notifyListeners();
}

bool isCut(String path) {
  return _clipboardIsCut && (_clipboardPaths?.contains(path) ?? false);
}
```

### 4.3 حوارات التأكيد

```dart
// حوار تأكيد الحذف
class DeleteConfirmDialog extends StatelessWidget {
  final List<FileTreeItem> items;
  // "Are you sure you want to delete 'filename'?"
  // "Are you sure you want to delete 3 files?"
  // [Move to Trash] [Delete Permanently] [Cancel]
}

// حوار تعارض النقل
class MoveConflictDialog extends StatelessWidget {
  final String sourceName;
  final String targetDir;
  // "A file or folder with the name 'X' already exists. 
  //  Do you want to replace it?"
  // [Replace] [Skip] [Cancel]
}
```

### 4.4 اختصارات لوحة المفاتيح

```dart
// في ExplorerTree:
Focus(
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent) {
      // F2 → إعادة تسمية
      // Delete → حذف
      // Ctrl+C → نسخ
      // Ctrl+X → قص
      // Ctrl+V → لصق
      // Enter → فتح الملف / توسيع المجلد
      // ArrowUp/Down → التنقل
      // ArrowRight → توسيع المجلد
      // ArrowLeft → طي المجلد
      // Home → أول عنصر
      // End → آخر عنصر
      // Ctrl+Shift+C → نسخ المسار النسبي
    }
  },
  child: ExplorerTree(),
)
```

### 4.5 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 4.1 | تنفيذ قائمة السياق | `explorer_tree.dart` | 3.6 |
| 4.2 | تنفيذ عمليات الحافظة (Cut/Copy/Paste) | `file_explorer_controller.dart` | 2.5 |
| 4.3 | إنشاء `DeleteConfirmDialog` | `dialogs/delete_confirm_dialog.dart` | — |
| 4.4 | إنشاء `MoveConflictDialog` | `dialogs/move_conflict_dialog.dart` | — |
| 4.5 | ربط `InlineRenameField` مع `startRename()` | `file_tree_tile.dart` | 3.2, 3.3, 2.5 |
| 4.6 | تنفيذ إنشاء ملف/مجلد جديد مع Inline Input | `explorer_tree.dart` | 3.3, 2.5 |
| 4.7 | تنفيذ اختصارات لوحة المفاتيح | `explorer_tree.dart` | 4.1-4.6 |
| 4.8 | تنفيذ نسخ المسار إلى الحافظة | `file_explorer_controller.dart` | — |

### معيار الاكتمال ✅

- [x] قائمة سياق كاملة بالنقر الأيمن
- [x] إنشاء ملف/مجلد جديد مع حقل إدخال مباشر
- [x] إعادة تسمية مباشرة (F2)
- [x] حذف مع حوار تأكيد
- [x] قص/نسخ/لصق يعمل
- [x] اختصارات لوحة المفاتيح تعمل
- [x] العنصر المقصوص يظهر بشفافية 0.5

---

## المرحلة 5: السحب والإفلات والتحسينات

**المدة المقدرة:** 1-2 جلسات | **الأولوية:** 🟡 مهمة

### الهدف

إضافة السحب والإفلات + Auto-Reveal + تحسينات بصرية.

### 5.1 السحب والإفلات

```dart
/// دعم Drag & Drop داخل الشجرة
/// مستوحى من FileDragAndDrop في VS Code
class DraggableTreeTile extends StatelessWidget {
  // السلوك:
  // 1. سحب ملف/مجلد → يمكن إفلاته على مجلد آخر
  // 2. لا يمكن إفلات مجلد على نفسه أو أبنائه
  // 3. مؤشر بصري: خلفية list-dropBackground عند المرور
  // 4. Ctrl + إفلات = نسخ بدل نقل
  // 5. تأخير 800ms قبل فتح مجلد مغلق عند المرور عليه
}
```

**التنفيذ في Flutter:**

```dart
// في FileTreeTile:
Draggable<FileTreeItem>(
  data: item,
  feedback: _buildDragFeedback(item),
  childWhenDragging: Opacity(opacity: 0.5, child: child),
  child: DragTarget<FileTreeItem>(
    onWillAcceptWithDetails: (details) {
      // لا تقبل إفلات على نفسه أو أبنائه
      return item.isDirectory && 
             details.data.path != item.path &&
             !item.path.startsWith(details.data.path);
    },
    onAcceptWithDetails: (details) {
      controller.move([details.data.path], item.path);
    },
    builder: (context, candidateData, rejectedData) {
      final isDropTarget = candidateData.isNotEmpty;
      return Container(
        color: isDropTarget 
          ? theme.listDropBackground 
          : Colors.transparent,
        child: /* ... */,
      );
    },
  ),
)
```

### 5.2 Auto-Reveal (الكشف التلقائي)

```dart
// عند فتح ملف في المحرر → إظهاره في الشجرة
// مستوحى من explorer.autoReveal في VS Code

// في ExplorerView.initState():
editorController.addListener(() {
  final activeTab = editorController.activeTab;
  if (activeTab != null && autoReveal) {
    explorerController.revealAndSelect(activeTab.path);
  }
});

// في FileExplorerController:
Future<void> revealAndSelect(String path) async {
  // 1. فتح كل المجلدات الأب
  await expandTo(path);
  // 2. تحديد العنصر
  select(findItem(path)!);
  // 3. التمرير إليه (اختياري)
}
```

### 5.3 تحسينات بصرية

```dart
// 1. Indent Guides (خطوط المسافة البادئة)
// خطوط رأسية رفيعة توضح مستوى التداخل
class IndentGuides extends StatelessWidget {
  final int depth;
  final Color guideColor;  // theme.treeIndentGuidesStroke
}

// 2. تحريك التوسيع/الطي
// سهم التوسيع يدور بـ AnimatedRotation
AnimatedRotation(
  turns: isExpanded ? 0.25 : 0.0,  // 90°
  duration: Duration(milliseconds: 150),
  child: Icon(Icons.chevron_right, size: 14),
)

// 3. شريط التمرير المخصص
// رفيع وشفاف حتى المرور
Scrollbar(
  thickness: 6,
  thumbVisibility: false,  // يظهر عند المرور فقط
  child: ExplorerTree(),
)

// 4. Highlight عند البحث
// CountBadge يظهر عدد النتائج بجانب المجلدات المطوية
```

### 5.4 فلترة الملفات المخفية

```dart
// في FileExplorerController:
Set<String> _excludePatterns = {
  '.git', '.dart_tool', 'build', '.idea',
  '.vscode', 'node_modules', '.DS_Store',
};

bool _shouldShow(FileTreeItem item) {
  if (_excludePatterns.contains(item.name)) return false;
  if (!_showHiddenFiles && item.isHidden) return false;
  return true;
}
```

### 5.5 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 5.1 | تنفيذ Draggable + DragTarget | `file_tree_tile.dart` | 3.2 |
| 5.2 | تنفيذ منطق عدم إفلات على النفس/الأبناء | `file_tree_tile.dart` | 5.1 |
| 5.3 | تنفيذ Auto-Reveal | `explorer_view.dart` | 3.7, 2.3 |
| 5.4 | إضافة Indent Guides | `file_tree_tile.dart` | 3.2 |
| 5.5 | إضافة تحريك سهم التوسيع | `file_tree_tile.dart` | 3.2 |
| 5.6 | تنفيذ فلترة الملفات المخفية | `file_explorer_controller.dart` | 2.4 |
| 5.7 | تنفيذ فتح تلقائي للمجلد عند المرور أثناء السحب | `file_tree_tile.dart` | 5.1 |

### معيار الاكتمال ✅

- [x] سحب وإفلات الملفات/المجلدات داخل الشجرة
- [x] مؤشر بصري واضح لموضع الإفلات
- [x] Auto-Reveal يعمل عند تبديل التبويبات
- [x] Indent Guides مرئية
- [x] الملفات المخفية (.git, build, ...) مفلترة
- [x] تحريكات سلسة للتوسيع/الطي

---

## المرحلة 6: التكامل والتحسينات المتقدمة

**المدة المقدرة:** 1-2 جلسات | **الأولوية:** 🟢 تحسينية

### الهدف

تكامل مع الأنظمة الموجودة + تحسينات أداء + ميزات متقدمة.

### 6.1 التكامل مع LSP

```dart
// عند فتح/إغلاق ملف → إخطار LSP
// في ExplorerTree._openFileInEditor():
Future<void> _openFileInEditor(EditorDocumentsController editor, FileTreeItem item) async {
  final content = await fileService.readFileContent(item.path);
  editor.openFile(
    title: item.name,
    path: item.path,
    languageId: fileService.resolveLanguageId(item.name),
    content: content,
  );
  // LSP يُخطَر تلقائياً عبر LspDocumentTracker
}
```

### 6.2 التكامل مع Terminal

```dart
// "Open in Terminal" من قائمة السياق
void openInTerminal(FileTreeItem item) {
  final dir = item.isDirectory ? item.path : item.parent?.path;
  if (dir != null) {
    executionController.openTerminal(workingDirectory: dir);
  }
}
```

### 6.3 البحث في الملفات (Find in Explorer)

```dart
/// بحث سريع في أسماء الملفات
/// مستوحى من ExplorerFindProvider في VS Code
class ExplorerSearchBar extends StatelessWidget {
  // يظهر عند Ctrl+F في الشجرة
  // وضعان:
  // 1. Filter: يُخفي غير المطابقين
  // 2. Highlight: يُبرز المطابقين فقط
}
```

### 6.4 Decorations (تزيينات)

```dart
// عرض معلومات إضافية بجانب اسم الملف:
// - Git status (modified: M, untracked: U, ...)
// - Errors count من diagnostics
// - Symbolic link indicator (↷)

class FileDecorations {
  final String? badge;       // حرف أو رقم
  final Color? badgeColor;   // لون الشارة
  final Color? nameColor;    // لون الاسم (مثل modified → أخضر)
  final String? tooltip;     // تلميح
}
```

### 6.5 تحسينات الأداء

```dart
// 1. حفظ واستعادة حالة التوسيع
void saveState() {
  // حفظ _expandedPaths في SharedPreferences
}
void restoreState() {
  // استعادة _expandedPaths عند فتح التطبيق
}

// 2. تحسين getVisibleItems()
// كش النتيجة وإعادة الحساب فقط عند التغيير
List<FileTreeItem>? _cachedVisibleItems;
bool _isDirty = true;

List<FileTreeItem> getVisibleItems() {
  if (!_isDirty && _cachedVisibleItems != null) {
    return _cachedVisibleItems!;
  }
  _cachedVisibleItems = _computeVisibleItems();
  _isDirty = false;
  return _cachedVisibleItems!;
}

// 3. تجاهل التحديثات السريعة المتتالية
// RunOnceScheduler pattern من VS Code
Timer? _refreshDebouncer;
void _scheduleRefresh() {
  _refreshDebouncer?.cancel();
  _refreshDebouncer = Timer(
    Duration(milliseconds: 500),
    () => refresh(),
  );
}
```

### 6.6 مهام المرحلة

| # | المهمة | الملف | التبعيات |
| --- | -------- | ------ | ---------- |
| 6.1 | ربط فتح الملفات مع قراءة المحتوى الحقيقي | `explorer_tree.dart` | 1.3, 3.6 |
| 6.2 | ربط مع Terminal (Open in Terminal) | `explorer_tree.dart` | — |
| 6.3 | إنشاء `ExplorerSearchBar` | `widgets/explorer_search_bar.dart` | 2.2 |
| 6.4 | إنشاء `FileDecorations` نظام | `widgets/file_tree_tile.dart` | 3.2 |
| 6.5 | حفظ/استعادة حالة التوسيع | `file_explorer_controller.dart` | 2.2 |
| 6.6 | تحسين أداء `getVisibleItems()` | `file_explorer_controller.dart` | 2.4 |
| 6.7 | تنفيذ debounce للتحديثات | `file_explorer_controller.dart` | 2.6 |

### معيار الاكتمال ✅

- [x] الملفات تُفتح من نظام الملفات الحقيقي
- [x] حالة التوسيع محفوظة بين الجلسات
- [x] البحث في أسماء الملفات يعمل في المجلدات غير المحمّلة
- [x] تحميل وعرض 1000 ملف في اختبار وحدة مع تخزين نتيجة العرض مؤقتاً

---

## ملخص الجدول الزمني

```text
المرحلة 1 ─── نموذج البيانات + FileSystemService ──────── [جلسة 1-2]
    │                                                        🔴 حرج
    ▼
المرحلة 2 ─── Controller + FileWatcher ─────────────────── [جلسة 3-4]
    │                                                        🔴 حرج
    ▼
المرحلة 3 ─── واجهة العرض (Tree + Icons + Tiles) ────────── [جلسة 5-7]
    │                                                        🔴 حرج
    ▼
المرحلة 4 ─── CRUD + Context Menu + Keyboard ────────────── [جلسة 8-9]
    │                                                        🟡 مهم
    ▼
المرحلة 5 ─── Drag & Drop + Auto-Reveal + Polish ────────── [جلسة 10-11]
    │                                                        🟡 مهم
    ▼
المرحلة 6 ─── تكامل + بحث + أداء ──────────────────────── [جلسة 12-13]
                                                             🟢 تحسيني
```

---

## ملخص الملفات الجديدة (بالترتيب)

| # | الملف | المرحلة | الوصف |
| --- | ------- | --------- | ------- |
| 1 | `core/file_system/models/file_tree_item.dart` | 1 | نموذج عنصر الشجرة |
| 2 | `core/file_system/models/sort_config.dart` | 1 | إعدادات الترتيب |
| 3 | `core/file_system/services/file_system_service.dart` | 1 | خدمة نظام الملفات |
| 4 | `core/file_system/services/file_watcher_service.dart` | 2 | مراقب التغييرات |
| 5 | `core/file_system/controllers/file_explorer_controller.dart` | 2 | وحدة التحكم |
| 6 | `core/file_system/services/file_icon_resolver.dart` | 3 | أيقونات الملفات |
| 7 | `parts/sidebar/explorer/widgets/file_tree_tile.dart` | 3 | عنصر الشجرة |
| 8 | `parts/sidebar/explorer/widgets/inline_rename_field.dart` | 3 | حقل إعادة التسمية |
| 9 | `parts/sidebar/explorer/widgets/section_header.dart` | 3 | رأس القسم |
| 10 | `parts/sidebar/explorer/widgets/open_editors_list.dart` | 3 | المحررات المفتوحة |
| 11 | `parts/sidebar/explorer/explorer_tree.dart` | 3 | شجرة الملفات |
| 12 | `parts/sidebar/explorer/explorer_view.dart` | 3 | العرض الرئيسي |
| 13 | `parts/sidebar/explorer/dialogs/delete_confirm_dialog.dart` | 4 | حوار الحذف |
| 14 | `parts/sidebar/explorer/dialogs/move_conflict_dialog.dart` | 4 | حوار تعارض النقل |
| 15 | `parts/sidebar/explorer/widgets/explorer_search_bar.dart` | 6 | بحث الملفات |

**الملفات المُحدَّثة:**

- `parts/sidebar/sidebar_widget.dart` — استبدال الشجرة الثابتة بـ `ExplorerView`
- `main.dart` — تسجيل `FileExplorerScope`
- `models/editor_tab_item.dart` — إضافة `isPreview` support

---

## سجل التنفيذ

**آخر تحديث:** 2026-10-28  
**الحالة:** تنفيذ المراحل 1–6 والتحقق النهائي مكتمل.

### ما تم تنفيذه

- طبقة نظام الملفات: نموذج شجري كسول، ترتيب، وقراءة/إنشاء/حذف/إعادة تسمية/نقل/نسخ الملفات، مع تجنب اتباع الروابط الرمزية أثناء الاستعراض والبحث.
- وحدة التحكم والمراقبة: فتح مساحة العمل، التحميل الكسول، ترتيب وفلترة وبحث شامل داخل المجلدات غير المحمّلة، وضعي البحث Filter وHighlight، تحديد متعدد، قص/نسخ/لصق، استعادة المجلدات المفتوحة، تحديثات مراقب الملفات وحالة Git، وتخزين نتيجة القائمة المرئية مؤقتاً.
- واجهة Explorer: أيقونات ديناميكية، عرض افتراضي 22px، توسيع متحرك، أدلة التداخل، تمييز نتائج البحث وشارات Git (M/A/D/R/U)، محررات مفتوحة، إعادة تسمية مباشرة، قائمة سياق، إنشاء وحذف مع تأكيد، تعارضات النقل، اختصارات لوحة المفاتيح، السحب والإفلات، والكشف التلقائي.
- تكامل المحرر: فتح محتوى الملفات الحقيقية بمعاينة قابلة للاستبدال/التثبيت، حفظ التعديلات إلى القرص عبر Ctrl/Cmd+S، تحديث مسارات التبويبات بعد النقل/إعادة التسمية، وربط LSP بجذر مساحة العمل.
- تسجيل النطاقات والخدمات في `main.dart`، واستبدال المستكشف الثابت. إدخال مسار المجلد هو آلية اختيار مساحة العمل الحالية ولا يتطلب إضافة حزمة اختيار ملفات.
- اختبارات وحدة لعمليات الملفات، المراقبة، البحث في المجلدات غير الموسعة بوضعَي Filter وHighlight، تصنيف حالات Git بما فيها المسارات ذات المسافات، التحديث بعد العمليات الجزئية، التبويبات، الحفظ، وتحميل 1000 ملف.

### نتائج التحقق

- `flutter analyze`: ناجح بلا ملاحظات.
- `flutter test` لاختبارات الملفات/المستكشف/التبويبات/التنفيذ/LSP: ناجح (`31` اختباراً).
- اختبار الأداء الحالي يقيس صحة تحميل 1000 عنصر وإعادة استخدام القائمة المحسوبة؛ لا توجد ميزانية زمنية محددة في الخطة لقياسها.
- `flutter test test/widget_test.dart`: ناجح؛ شُغّل بعد اكتمال التعديلات والتحليل واختبارات الوحدات كآخر تحقق، التزاماً بطلب تأجيل اختبار الواجهة.
