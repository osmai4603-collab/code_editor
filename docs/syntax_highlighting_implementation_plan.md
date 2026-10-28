# الخطة التنفيذية لبناء نظام تلوين الأكواد والتوليد الدلالي (Code Highlighting & Tokenization Engine)

> **مرجع الخطة:** مستندة بالكامل إلى التحليل المعماري لكود VS Code المصدري في:  
> [`docs/vscode_syntax_highlighting_and_tokenization_architecture.md`](file:///home/osm/flutter_projects/code_editor/docs/vscode_syntax_highlighting_and_tokenization_architecture.md)  
> **الهدف:** بناء محرك تلوين متقدم عالي الأداء لمشروع محرر الأكواد في Flutter (`code_editor`)، يجمع بين التلوين النحوي الفوري اللحظي (Syntactic Highlighting)، والتلوين الدلالي الذكي عبر LSP (Semantic Tokens)، وتلوين أزواج الأقواس المتداخلة (Bracket Pairs)، معتمداً على الترميز الثنائي 32-bit لمنع استهلاك الذاكرة وتفادي ضغط الـ Garbage Collection في Flutter.

---

## 🧭 الرؤية والمبادئ المعمارية الحاكمة (Guiding Architectural Principles)

1. **الاستجابة اللحظية دون تأخير في الكتابة (Zero Input Latency):**
   - الكتابة وتعديل النصوص يجب ألا تتأخر إطلاقاً (أقل من 1ms).
   - يتم تلوين السطر المعدل فورياً عبر طبقة النحو (Syntactic Layer)، بينما يتم جلب التلوين الدلالي الدقيق (Semantic Layer) في الخلفية بشكل غير متزامن (Asynchronous) دون حظر الواجهة.
2. **الترميز الثنائي المضغوط (32-Bit Integer Metadata):**
   - استلهام نموذج VS Code بعدم إنشاء كائنات `Token` أو `TextStyle` لكل كلمة وتخزينها في الذاكرة.
   - يتم تخزين معلومات الرمز (اللون، النمط، نوع الرمز، الأقواس) كأرقام صحيحة داخل مصفوفة `Int32List`، مما يوفر 95% من الذاكرة مقارنة بإنشاء كائنات Dart لكل رمز.
3. **التلوين ثنائي الطبقات المدمج (Two-Layered Architecture with Bitmask Merging):**
   - **الطبقة 1 (Syntactic):** محلل نحوي موضعي سريع جداً (Lexer) يغطي كامل السطر (Contiguous).
   - **الطبقة 2 (Semantic):** رموز دلالية متفرقة (Sparse) قادمة من خادم اللغة (LSP) لتحديد المتغيرات والدوال والفئات بدقة متناهية.
   - دمج الطبقتين عبر الأقنعة البتية (Bitwise Masking) بسلاسة فائقة.
4. **التخزين المؤقت للأنماط والأسطر (Line-Level Memoization & Style Caching):**
   - يعيد المحرر حساب `TextSpan` للأسطر المعدلة فقط، بينما الأسطر غير المتأثرة يتم استرجاعها مباشرة من الذاكرة المؤقتة (Cache).
   - توحيد الـ `TextStyle` عبر لوحة ألوان مركزية جاهزة (Flyweight Palette) بدلاً من إنشاء `TextStyle(...)` جديد في كل إطار رسم.
5. **تكامل متسق مع عناصر LSP والتشخيصات:**
   - دمج خطوط الأخطاء المتعرجة (Error Squiggles) والأقواس الملونة بسلاسة داخل نفس طبقة التوليد النصي `TextSpan`.

---

## 📊 خارطة المراحل المتسلسلة (Phases Roadmap)

```text
المرحلة 1: نموذج الذاكرة والترميز الثنائي (Binary Encoding & Memory Model)
  └─ بناء TokenMetadata و MetadataConsts و LineTokens اعتماداً على Int32List
       ↓
المرحلة 2: لوحة الألوان ومطابقة الثيمات (Theme Palette & Token Style System)
  └─ بناء TokenColorPalette و EditorTokenTheme وربط معرّفات ColorId بأنماط TextStyle
       ↓
المرحلة 3: المحلل النحوي السريع (Layer 1: Fast Syntactic Lexer)
  └─ بناء SyntacticTokenizer للدارت واللغات الأساسية مع حفظ حالات نهاية الأسطر
       ↓
المرحلة 4: عميل الرموز الدلالية في LSP (Layer 2: LSP Semantic Tokens Feature)
  └─ إضافة نماذج SemanticTokens لـ LSP واستقبال المصفوفة الخماسية المضغوطة بالـ Debouncer
       ↓
المرحلة 5: محرك الدمج الثنائي بالأقنعة (Bitmask Token Merging Engine)
  └─ تطبيق خوارزمية addSparseTokens لدمج الرموز الدلالية مع النحوية بتياً
       ↓
المرحلة 6: تلوين أزواج الأقواس المتداخلة (Bracket Pairs Colorizer)
  └─ تتبع مستويات الأقواس () و {} و [] وتلوينها دورياً بألوان العمق 1..6
       ↓
المرحلة 7: محرك العرض في Flutter والتكامل مع المحرر (Rendering Controller)
  └─ بناء CodeEditorController وتجاوز buildTextSpan مع التخزين المؤقت وخطوط الأخطاء
       ↓
المرحلة 8: اختبارات الأداء والجودة والضغط (Benchmarking & Hardening)
  └─ اختبارات على ملفات تفوق 10,000 سطر وتأكيد الحفاظ على 60+ FPS واختبارات الوحدة
```

---

## 🏗️ الهيكل البرمجي المقترح في المشروع (`lib/`)

```text
lib/
├── core/
│   ├── syntax/                                     # النظام الأساسي لتلوين الأكواد
│   │   ├── model/
│   │   │   ├── encoded_token_attributes.dart       # توزيع البتات 32-bit والعمليات الثنائية
│   │   │   ├── token_metadata.dart                 # فك وتركيب خصائص الرموز من العدد الصحيح
│   │   │   ├── line_tokens.dart                    # تمثيل رموز السطر الواحد عبر Int32List
│   │   │   └── line_token_builder.dart             # مساعد لبناء رموز الأسطر بكفاءة
│   │   │
│   │   ├── theme/
│   │   │   ├── token_color_palette.dart            # لوحة الألوان وخرائط ColorId -> Color
│   │   │   ├── editor_token_theme.dart             # تعريف قواعد الثيم للرموز النحوية والدلالية
│   │   │   └── default_dark_token_theme.dart       # ثيم VS Code Dark+ الافتراضي
│   │   │
│   │   ├── lexer/
│   │   │   ├── syntactic_lexer.dart                # الواجهة العامة لمحللات اللغات النحوية
│   │   │   ├── dart_syntactic_lexer.dart           # محلل فوري متزامن فائق السرعة للغة Dart
│   │   │   └── lexer_state.dart                    # حالة نهاية السطر لدعم التعليقات متعددة الأسطر
│   │   │
│   │   ├── semantic/
│   │   │   ├── sparse_tokens_store.dart            # مخزن الرموز الدلالية المتفرقة
│   │   │   ├── semantic_tokens_merger.dart         # خوارزمية دمج الأقنعة البتية (Bitmask Merger)
│   │   │   └── semantic_tokens_styling.dart        # ربط أنواع ومعدلات LSP بلوحة الثيم
│   │   │
│   │   └── brackets/
│   │       ├── bracket_pair_info.dart              # تمثيل موضع القوس وعمقه ونوعه
│   │       └── bracket_colorizer.dart              # محلل ومطابق أزواج الأقواس بألوان العمق 1..6
│   │
│   └── lsp/
│       ├── protocol/
│       │   └── lsp_semantic_tokens_types.dart      # نماذج SemanticTokens, Legend, Edits
│       └── features/
│           └── semantic_tokens_manager.dart        # إدارة طلبات textDocument/semanticTokens
│
└── parts/
    └── editor/
        ├── controllers/
        │   └── code_editor_controller.dart         # محكم تحرير الكود المخصص وباني الـ TextSpan
        └── rendering/
            └── line_text_span_cache.dart           # التخزين المؤقت للأسطر الملونة لسرعة الرسم
```

---

## 🚀 المراحل التنفيذية التفصيلية

---

### المرحلة 1: نموذج الذاكرة والترميز الثنائي (Binary Encoding & Memory Model)

#### الهدف

بناء البنية الأساسية منخفضة المستوى لتمثيل الرموز النحوية كأعداد صحيحة 32-bit وتخزينها في مصفوفات بايتية مستمرة، تماماً كما يفعل VS Code.

#### المهام التنفيذية

1. **إنشاء [encoded_token_attributes.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/model/encoded_token_attributes.dart):**
   - تعريف التوزيع البتي 32-bit:
     - بت 0..7: `languageId` (8 بت - حتى 256 لغة).
     - بت 8..9: `tokenType` (2 بت: عادي=0، تعليق=1، نص=2، تعبير نمطي=3).
     - بت 10: `isBracket` (1 بت: هل الرمز قوس متوازن).
     - بت 11..14: `fontStyle` (4 بت: غامق=1، مائل=2، تسطير=4، شطب=8).
     - بت 15..23: `foreground` (9 بت - حتى 512 معرف لون `ColorId`).
     - بت 24..31: `background` (8 بت - لون خلفية الرمز إن وجد).
   - تعريف أقنعة البتات الثنائية (`LANGUAGE_MASK`, `FOREGROUND_MASK`, إلخ).
   - تعريف أقنعة التحكم الدلالية:

     ```dart
     static const int semanticUseItalic = 0x01;
     static const int semanticUseBold = 0x02;
     static const int semanticUseUnderline = 0x04;
     static const int semanticUseForeground = 0x10;
     ```

2. **إنشاء [token_metadata.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/model/token_metadata.dart):**
   - دوال مساعدة استاتيكية للتشفير وفك التشفير:
     - `int encode({...})`
     - `int getForeground(int metadata)`
     - `int getFontStyle(int metadata)`
     - `int getTokenType(int metadata)`
     - `bool isBold(int metadata)`, `bool isItalic(int metadata)`
3. **إنشاء [line_tokens.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/model/line_tokens.dart):**
   - تمثيل رموز السطر الواحد عبر مصفوفة `Int32List`:
     - الأزواج: `[endOffset0, metadata0, endOffset1, metadata1, ...]`.
   - توفير دوال سريعة:
     - `int get count => binaryTokens.length ~/ 2;`
     - `int getEndOffset(int tokenIndex)`
     - `int getMetadata(int tokenIndex)`
     - `int findTokenIndexAtOffset(int charOffset)` (عبر البحث الثنائي Binary Search).

---

### المرحلة 2: لوحة الألوان ونظام الثيمات (Theme Palette & Token Style)

#### الهدف

إدارة لوحة الألوان وتعيين `ColorId` لكل لون مستخدم، وتحويل الأرقام الثنائية إلى كائنات `TextStyle` بأسلوب Flyweight فائق السرعة ومخزن مسبقاً.

#### المهام التنفيذية

1. **إنشاء [token_color_palette.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/theme/token_color_palette.dart):**
   - إدارة مصفوفة ألوان فريدة `List<Color>`.
   - الألوان الأساسية الافتراضية للثيم الداكن:
     - 1: الافتراضي (`#D4D4D4`).
     - 2: الكلمات المحجوزة (`#569CD6` - أزرق).
     - 3: الكلمات المحجوزة للتحكم مثل if/return (`#C586C0` - بنفسجي).
     - 4: النصوص (Strings) (`#CE9178` - برتقالي فاتح).
     - 5: التعليقات (`#6A9955` - أخضر).
     - 6: الأرقام (`#B5CEA8` - أخضر مائل للزرقة).
     - 7: الفئات والأنواع (Types/Classes) (`#4EC9B0` - تركواز).
     - 8: الدوال والطرق (Functions/Methods) (`#DCDCAA` - أصفر).
     - 9: المتغيرات المحلية والمعاملات (`#9CDCFE` - سماوي).
     - 10: الثوابت والحقول الثابتة (`#4FC1FF` - أزرق سماوي ساطع).
2. **إنشاء [editor_token_theme.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/theme/editor_token_theme.dart):**
   - تخزين مؤقت لكائنات `TextStyle` مجمعة وفق مفتاح `(colorId, fontStyle)` لتجنب استدعاء `TextStyle(...)` المتكرر أثناء الرسم:

     ```dart
     TextStyle getStyle(int colorId, int fontStyle, {double fontSize = 13.5, String fontFamily = 'monospace'})
     ```

   - توفير واجهة لتخصيص الألوان لكل لغة وتوافق كامل مع ثيمات VS Code.

---

### المرحلة 3: المحلل النحوي السريع (Layer 1: Fast Syntactic Lexer)

#### الهدف

بناء محلل نحوي فوري متزامن (Synchronous Line-by-Line Lexer) يعمل أثناء الكتابة مباشرة، بحيث يعود بنتيجة تلوين فورية لكل سطر قبل استجابة خادم اللغة.

#### المهام التنفيذية

1. **إنشاء [syntactic_lexer.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/lexer/syntactic_lexer.dart):**
   - الواجهة العامة:

     ```dart
     abstract class SyntacticLexer {
       LineTokens tokenizeLine(String line, LexerState previousState);
     }
     ```

   - دعم نقل الحالة `LexerState` بين الأسطر (لحالات: تعليق متعدد الأسطر `/* ... */`، أو نصوص متعددة الأسطر `'''...'''`).
2. **إنشاء [dart_syntactic_lexer.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/lexer/dart_syntactic_lexer.dart):**
   - محلل فائق السرعة يعتمد على الفحص الحرفي (Character Scanning) والـ Trie/Lookup Tables دون تعبيرات نمطية ثقيلة (No backtracking).
   - التعرف الدقيق على:
     - **الكلمات المحجوزة (Keywords):** `class, void, var, final, const, if, else, for, while, return, await, async, import, export, switch, case, try, catch...`
     - **الأنواع المضمنة (Built-in Types):** `int, double, String, bool, List, Map, Set, Future, Stream, dynamic...`
     - **النصوص والهروب (Strings & Escapes):** نصوص مفردة ومزدوجة ونصوص خام `r'...'` والرموز التعبيرية داخل النص `${...}`.
     - **التعليقات (Comments):** أحادية `//` وتوثيقية `///` ومتعددة الأسطر `/* ... */`.
     - **الأرقام (Numbers):** الأعداد الصحيحة والعشرية والسداسية عشري `0xFF`.
     - **المعاملات والأقواس (Operators & Delimiters):** `+ - * / = == != => { } [ ] ( ) ; , .`.
   - توليد `LineTokens` للسطر الواحد في زمن أقل من **0.05 مللي ثانية**.

---

### المرحلة 4: عميل الرموز الدلالية في LSP (Layer 2: LSP Semantic Tokens)

#### الهدف

ربط خادم اللغة لاستقبال الرموز الدلالية الحقيقية (Semantic Tokens) القادمة من الـ Compiler/Analyzer وتفسيرها بالكامل.

#### المهام التنفيذية

1. **تحديث [lsp_semantic_tokens_types.dart](file:///home/osm/flutter_projects/code_editor/lib/core/lsp/protocol/lsp_semantic_tokens_types.dart):**
   - تعريف نموذج `SemanticTokensLegend` (قائمة أنواع الرموز مثل `['class', 'method', 'property', 'parameter', 'variable']` ومعدلاتها `['declaration', 'static', 'async', 'deprecated']`).
   - تعريف نموذج `SemanticTokens`:

     ```dart
     class SemanticTokens {
       final String? resultId;
       final List<int> data; // المصفوفة الخماسية المضغوطة
       ...
     }
     ```

2. **إنشاء [semantic_tokens_manager.dart](file:///home/osm/flutter_projects/code_editor/lib/core/lsp/features/semantic_tokens_manager.dart):**
   - إرسال طلب `textDocument/semanticTokens/full` عند فتح المستند، وعند توقف المستخدم عن الكتابة عبر مؤقت الـ Debounce (300ms إلى 800ms).
   - فك ترميز المصفوفة الخماسية:
     - `line += deltaLine`
     - `char = (deltaLine == 0 ? char + deltaStartChar : deltaStartChar)`
     - قراءة `length` و `tokenTypeIndex` و `tokenModifiersBitmask`.
   - تحويل الرموز المفكوكة إلى كائنات دلالية وتخزينها في `SparseTokensStore`.

---

### المرحلة 5: محرك الدمج الثنائي بالأقنعة (Bitmask Token Merging Engine)

#### الهدف

تطبيق خوارزمية الدمج البتية الدقيقة المستوحاة من VS Code (`SparseTokensStore.addSparseTokens`) لدمج الرموز الدلالية فوق الرموز النحوية دون تعارض.

#### المهام التنفيذية

1. **إنشاء [sparse_tokens_store.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/semantic/sparse_tokens_store.dart):**
   - حفظ الرموز الدلالية لكل سطر في هياكل سريعة الوصول.
2. **إنشاء [semantic_tokens_merger.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/semantic/semantic_tokens_merger.dart):**
   - تنفيذ دالة الدمج:

     ```dart
     LineTokens mergeLineTokens(LineTokens syntactic, SparseLineTokens? semantic)
     ```

   - خوارزمية السير المتوازي بمؤشرين `syntacticIndex` و `semanticIndex`:
     1. إضافة الرموز النحوية السابقة للرمز الدلالي كما هي.
     2. عند حدوث تداخل (Overlap)، استخراج قناع الخصائص التي حددها الرمز الدلالي:

        ```dart
        final bMask = (
          (bMeta & MetadataConsts.semanticUseForeground != 0 ? MetadataConsts.foregroundMask : 0) |
          (bMeta & MetadataConsts.semanticUseBold != 0 ? MetadataConsts.boldMask : 0) |
          (bMeta & MetadataConsts.semanticUseItalic != 0 ? MetadataConsts.italicMask : 0)
        );
        final aMask = ~bMask;
        final mergedMeta = (aMeta & aMask) | (bMeta & bMask);
        ```

     3. النتيجة: دمج فوري فائق السرعة يحتفظ بنوع الرمز وأقواسه من النحو، ويأخذ لونه وتأثيراته من الدلالة.

---

### المرحلة 6: تلوين أزواج الأقواس المتداخلة (Bracket Pairs Colorizer)

#### الهدف

التعرف على الأقواس `()`, `{}`, `[]` وحساب مستوى التداخل (Nesting Level)، وتلوين كل زوج بنفس اللون لإعطاء تجربة بصرية فائقة الوضوح مطابقة لـ VS Code Bracket Pair Colorization.

#### المهام التنفيذية

1. **إنشاء [bracket_colorizer.dart](file:///home/osm/flutter_projects/code_editor/lib/core/syntax/brackets/bracket_colorizer.dart):**
   - مصفوفة ألوان الأقواس الستة الافتراضية:
     - المستوى 1: أصفر ذهبي (`#FFD700`).
     - المستوى 2: بنفسجي أوركيد (`#DA70D6`).
     - المستوى 3: أزرق سماوي (`#179FFF`).
     - تتكرر الألوان دورياً للمستويات الأعمق (`level % 3`).
   - خوارزمية فحص مكدس الأقواس (Bracket Stack) سريعة ومحدثة مع السطور.
   - تعديل قيمة `metadata` للقوس ليحمل معرف لون القوس المناسب لمستواه، أو تزويده كطبقة زخرفة مضمنة.

---

### المرحلة 7: محرك العرض في Flutter والتكامل مع المحرر (Rendering Controller)

#### الهدف

استبدال `TextEditingController` الافتراضي بمحكم مخصص عالي الأداء يولد `TextSpan` ملوناً لكل سطر مع التخزين المؤقت، وتوصيله بـ [editor_area_widget.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/editor/editor_area_widget.dart).

#### المهام التنفيذية

1. **إنشاء [code_editor_controller.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/editor/controllers/code_editor_controller.dart):**
   - يرث من `TextEditingController` ويتجاوز الدالة:

     ```dart
     @override
     TextSpan buildTextSpan({
       required BuildContext context,
       TextStyle? style,
       required bool withComposing,
     })
     ```

   - قراءة السطور وتلوينها عبر مخرجات `LineTokens` المدمجة.
   - تحويل رموز كل سطر إلى قائمة `TextSpan` مقتضبة تجمع الكلمات المتطابقة في النمط.
2. **إنشاء [line_text_span_cache.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/editor/rendering/line_text_span_cache.dart):**
   - تخزين مؤقت لـ `TextSpan` لكل سطر لم يتغير محتواه أو حالته النحوية.
   - عند الضغط على مفتاح، يتم إعادة حساب السطر الحالي فقط (أو الأسطر المتأثرة بالسطر الجديد)، بينما تبقى بقية آلاف الأسطر في الكاش دون معالجة!
3. **دمج خطوط الأخطاء المتعرجة (Diagnostics Squiggles):**
   - قراءة الأخطاء من `DiagnosticsService` لكل سطر، وتطبيق:

     ```dart
     TextStyle(
       decoration: TextDecoration.underline,
       decorationStyle: TextDecorationStyle.wavy,
       decorationColor: Colors.redAccent,
     )
     ```

4. **تحديث [editor_area_widget.dart](file:///home/osm/flutter_projects/code_editor/lib/parts/editor/editor_area_widget.dart):**
   - تبديل `_textController = TextEditingController(...)` إلى `_codeController = CodeEditorController(...)`.
   - ربط المحكم بخدمة الـ LSP والـ Diagnostics والتحديث التلقائي عند استلام الرموز الدلالية.

---

### المرحلة 8: اختبارات الجودة والأداء والضغط (Benchmarking & Hardening)

#### الهدف

التحقق من كفاءة المحرك تحت الضغط، وضمان خلوه من أخطاء الذاكرة، والحفاظ على معدل إطارات سلس (60+ FPS).

#### المهام التنفيذية

1. **اختبارات الوحدة (Unit Tests):**
   - اختبارات صحة الترميز البتي لـ `TokenMetadata` والتأكد من عدم حدوث تجاوز في الـ Bits (Bit overflow).
   - اختبارات المحلل النحوي لـ Dart والتأكد من صحة تلوين التعليقات والنصوص والأرقام والكلمات المحجوزة.
   - اختبارات خوارزمية الدمج والتأكد من أسبقية الدلالة مع الحفاظ على النحو.
2. **اختبارات الأداء (Performance Benchmarks):**
   - قياس زمن تلوين ملف من 5,000 سطر (الهدف: أقل من 15ms لكامل الملف، وأقل من 0.1ms للسطر أثناء الكتابة).
   - قياس استهلاك الذاكرة والتأكد من استقرار الـ Heap دون تسريبات (Zero Memory Leaks).
3. **مراجعة تجربة المستخدم وسلاسة التمرير (60 FPS Scrolling):**
   - التأكد من ثبات معدل الإطارات أثناء التمرير السريع للأعلى والأسفل (Fast Scrolling).

---

## 📈 جدول مقارنة قبل وبعد تنفيذ الخطة

| المعيار | الوضع الحالي في المشروع | بعد تنفيذ الخطة المقترحة |
| --- | --- | --- |
| **التلوين النحوي** | نص رمادي موحد بلون واحد (Monochrome) | تلوين كامل احترافي مطابق لثيم VS Code Dark+ |
| **التلوين الدلالي (LSP)** | غير موجود | تمييز كامل بين الفئات، الطرق، المتغيرات، والحقول |
| **أزواج الأقواس** | لون موحد | تلوين ذكي دوري متداخل للمستويات 1..6 (Bracket Pairs) |
| **تظليل الأخطاء** | نقاط في الهامش الجانبي فقط | خطوط متعرجة حمراء/صفراء مدمجة تحت الكلمات مباشرة |
| **استهلاك الذاكرة** | غير محدد | مضغوط بتمثيل ثنائي 32-bit وذاكرة تخزين مؤقت للأسطر |
| **أداء الكتابة** | عادي | استجابة فورية (Sub-millisecond) دون حظر لخيط الواجهة |

---

## 🎯 معايير النجاح والقبول (Acceptance Criteria)

- [ ] ظهور الكود بألوان برمجية زاهية ومريحة للعين تطابق ثيم Dark+ فور فتح أي ملف Dart.
- [ ] تحديث تلوين السطر آنياً وبمجرد كتابة أي حرف دون أدنى تقطيع أو تأخير في المؤشر.
- [ ] استقبال الرموز الدلالية من Dart LSP وعكسها بسلاسة لتلوين أسماء الفئات والدوال بدقة.
- [ ] ظهور أزواج الأقواس المفتوحة والمغلقة بنفس اللون وفق مستوى التداخل.
- [ ] ظهور الخطوط المتعرجة تحت الأكواد التي تحتوي على أخطاء ترجمة بناءً على تشخيصات LSP.
- [ ] نجاح جميع اختبارات الوحدة الخاصة بالعمليات البتية والمحلل النحوي.
