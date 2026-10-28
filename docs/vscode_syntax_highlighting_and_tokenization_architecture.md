# معمارية تلوين الأكواد في VS Code (Code Highlighting & Tokenization Architecture)

> **توثيق معماري تحليلي شامل** لكيفية عمل نظام تلوين الأكواد وتوليد الرموز (Tokenization) في محرّر Visual Studio Code استناداً إلى الكود المصدري الرسمي في `/home/osm/Downloads/vscode-main/vscode-main/`.

---

## 1. الملخص التنفيذي وفلسفة التصميم (Executive Summary)

يُعد نظام تلوين الأكواد في VS Code إحدى أكثر المنظومات الهندسية نضجاً وتعقيداً في المحرر؛ حيث تم تصميمه لتحقيق ثلاثة أهداف متناقضة ظاهرياً:

1. **الاستجابة اللحظية (Sub-millisecond Typing Latency):** يجب ألا يتأخر الحرف المكتوب بأكثر من بضعة أجزاء من الألف من الثانية، بصرف النظر عن حجم الملف (حتى لو كان 100,000 سطر).
2. **الدقة الدلالية الفائقة (Semantic Accuracy):** التمييز الذكي بين المتغيرات المحلية (Local Variables)، الحقول (Fields)، الفئات (Classes)، الدوال غير المتزامنة (Async Functions)، والمتغيرات الثابتة (Constants) بالتعاون مع خوادم اللغة (LSP).
3. **كفاءة الذاكرة والأداء العالي (Memory Footprint & GC Pressure):** لا يُنشئ المحرر كائنات JavaScript منفصلة (Objects) لكل كلمة أو رمز في الملف، بل يُخزن الرموز النحوية في مصفوفات بايتية وأرقام ثنائية مدمجة بحجم 32 بت (`Uint32Array`).

### المكونات الرئيسية لمنظومة التلوين في VS Code

```text
                      ┌────────────────────────────────────────┐
                      │             TextModel                  │
                      │     (PieceTree Text Buffer)            │
                      └──────────────────┬─────────────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
   ┌───────────────────────────┐                   ┌───────────────────────────┐
   │ Layer 1: Syntactic Tokens │                   │ Layer 2: Semantic Tokens  │
   │  - TextMate (Oniguruma)   │                   │  - Language Server (LSP)  │
   │  - Tree-Sitter (Modern)   │                   │  - Debounced Async Poll   │
   │  ContiguousTokensStore    │                   │  SparseTokensStore        │
   │  (مصفوفة مستمرة متكاملة)    │                   │  (رموز دلالية متفرقة)      │
   └─────────────┬─────────────┘                   └─────────────┬─────────────┘
                 │                                               │
                 └───────────────────────┬───────────────────────┘
                                         │
                                         ▼
                         ┌───────────────────────────────┐
                         │      LineTokens Merger        │
                         │   (Bitmask Binary Merging)    │
                         └───────────────┬───────────────┘
                                         │
                                         ▼
                         ┌───────────────────────────────┐
                         │   Inline Bracket Decorator    │
                         │   (2-3 Tree Nested Brackets)  │
                         └───────────────┬───────────────┘
                                         │
                                         ▼
                         ┌───────────────────────────────┐
                         │       viewLineRenderer        │
                         │ HTML Spans (.mtk<id>) / GPU   │
                         └───────────────────────────────┘
```

---

## 2. التمثيل الثنائي للرموز: ضغط 32-Bit Token Metadata

أحد أهم الأسرار الهندسية في محرك Monaco/VS Code هو ملف:
`src/vs/editor/common/encodedTokenAttributes.ts`

بدلاً من تخزين كائن `Token` يحوي خصائص كـ (`color`, `fontStyle`, `language`, `tokenType`)، يتم حشر جميع خصائص الرمز داخل **عدد صحيح واحد بحجم 32-bit (Single 32-bit unsigned integer)** وفق التوزيع البتي التالي:

```text
  3322 2222 2222 1111 1111 1100 0000 0000  (Bit indices)
  1098 7654 3210 9876 5432 1098 7654 3210
 -------------------------------------------
  bbbb bbbb ffff ffff fFFF FBTT LLLL LLLL
 -------------------------------------------
  L = LanguageId          (8 bits: 0..255)
  T = StandardTokenType   (2 bits: Other=0, Comment=1, String=2, RegEx=3)
  B = Balanced Bracket    (1 bit)
  F = FontStyle           (4 bits: Italic, Bold, Underline, Strikethrough)
  f = Foreground ColorId  (9 bits: 0..511 فهرس لون في لوحة الثيم)
  b = Background ColorId  (8 bits: 0..255)
```

### الأقنعة البتية في الكود المصدري (`MetadataConsts`)

```typescript
export const enum MetadataConsts {
    LANGUAGEID_MASK        = 0b00000000_00000000_00000000_11111111,
    TOKEN_TYPE_MASK        = 0b00000000_00000000_00000011_00000000,
    BALANCED_BRACKETS_MASK = 0b00000000_00000000_00000100_00000000,
    FONT_STYLE_MASK        = 0b00000000_00000000_01111000_00000000,
    FOREGROUND_MASK        = 0b00000000_11111111_10000000_00000000,
    BACKGROUND_MASK        = 0b11111111_00000000_00000000_00000000,

    ITALIC_MASK            = 0b00000000_00000000_00001000_00000000,
    BOLD_MASK              = 0b00000000_00000000_00010000_00000000,
    UNDERLINE_MASK         = 0b00000000_00000000_00100000_00000000,
    STRIKETHROUGH_MASK     = 0b00000000_00000000_01000000_00000000,

    // بتات التحكم الدلالية (تُخبر المحرك بالخصائص التي يريد خادم LSP تعديلها)
    SEMANTIC_USE_ITALIC        = 0b00000001,
    SEMANTIC_USE_BOLD          = 0b00000010,
    SEMANTIC_USE_UNDERLINE     = 0b00000100,
    SEMANTIC_USE_STRIKETHROUGH = 0b00001000,
    SEMANTIC_USE_FOREGROUND    = 0b00010000,
    SEMANTIC_USE_BACKGROUND    = 0b00100000,
}
```

### كيف يمثل السطر الواحد داخل الذاكرة؟

لكل سطر، يتم تمثيل الرموز النحوية كمصفوفة أحادية من أرقام `Uint32Array`:
`[endOffset_0, metadata_0, endOffset_1, metadata_1, endOffset_2, metadata_2, ...]`

- `endOffset`: موضع نهاية الرمز داخل السطر (UTF-16 code units).
- `metadata`: الرقم الثنائي 32-bit المشروح أعلاه.

**الميزة:** سطر يحتوي على 20 كلمة يستهلك فقط مصفوفة بها 40 رقماً ثنائياً (160 بايت فقط!)، دون توليد أي كائنات Garbage Collection نهائياً.

---

## 3. الطبقة الأولى: التلوين النحوي (Syntactic Highlighting)

تقع هذه الطبقة في:
`src/vs/workbench/services/textMate/` و `src/vs/editor/common/model/tokens/`

### 3.1 محرك TextMate وقواعد Oniguruma

- يعتمد VS Code تاريخياً على قواعد **TextMate Grammars** (ملفات `.tmLanguage.json` أو `.tmLanguage.plist`).
- يتم تنفيذ التعبيرات النمطية العادية (RegEx) عبر محرك **Oniguruma** المترجم إلى **WebAssembly** (`vscode-oniguruma`) لضمان التوافق التام مع صياغات TextMate وسرعة C/C++.
- كل قاعدة نحوية تعمل كـ **آلة حالات منتهية لكل سطر (Line-by-line State Machine)**.
  - الدالة المركزية هي:

    ```typescript
    tokenizeEncoded(line: string, hasEOL: boolean, state: StateStack): EncodedTokenizationResult
    ```

  - يستقبل المحرك سطر النص وحالة السطر السابق (`StateStack`)، ويُخرج الرموز المشفرة مع الحالة الجديدة لنهاية السطر.
  - إذا لم تتغير حالة نهاية السطر بعد التعديل، يتوقف المحلل فوراً ولا يعيد تحليل بقية أسطر الملف!

### 3.2 المعالجة الهجينة بين واجهة المستخدم وخلفية Web Worker

لمنع تجميد الواجهة (UI Freezing):

1. **النافذة المرئية أولاً (Synchronous Viewport Tokenization):**
   - عندما يُمرر المستخدم الشاشة أو يفتح ملفاً، يستدعي المحرك `forceTokenization(lineNumber)` للأسطر المرئية في الشاشة فقط وبشكل فوري ومتزامن على الخيط الرئيسي.
2. **الخلفية غير المتزامنة (Background Web Worker Tokenizer):**
   - في الملف: `src/vs/workbench/services/textMate/browser/backgroundTokenization/textMateWorkerTokenizerController.ts`
   - يتم تشغيل Web Worker منفصل (`TextMateTokenizationWorker`).
   - عند كتابة أي نص، يرسل المحرر `$acceptModelChanged` إلى العامل في الخلفية.
   - يقوم العامل بتحليل كامل الملف تدريجياً، ويرسل النتائج على دفعات (Chunks) إلى `_backgroundTokenizationStore.setTokens(...)`.
3. **موازنة الوقت عند العمل على الخيط الرئيسي (`DefaultBackgroundTokenizer`):**
   - إذا تعذر استخدام Web Worker، يستعين المحرر بـ `runWhenGlobalIdle` بميزانية زمنية لا تتعدى `1ms - 2ms` لكل دورة قبل أن يعيد التحكم للمتصفح.

### 3.3 المعمارية الحديثة: دعم Tree-Sitter (Experimental)

في الإصدارات الحديثة من VS Code، أُضيف محرك Tree-Sitter:
`src/vs/editor/common/model/tokens/treeSitter/treeSitterSyntaxTokenBackend.ts`

- يستخدم مكتبة WebAssembly لتوليد Concrete Syntax Tree (CST).
- يُطبق استعلامات التلوين (Highlight Queries) المكتوبة بصيغة Scheme (`.scm`) مثل `highlights/typescript.scm`.
- يتميز بدعمه للتحليل المتزايد (Incremental Parsing) الحقيقي وتحديد نطاقات لغوية دقيقة جداً مقارنة بـ Regex.

---

## 4. الطبقة الثانية: التلوين الدلالي (Semantic Tokens via LSP)

تقع هذه الطبقة في:
`src/vs/editor/contrib/semanticTokens/` و `src/vs/editor/common/services/semanticTokensStyling.ts`

### 4.1 دور بروتوكول خادم اللغة (LSP)

النحو المجرد (TextMate) لا يعرف نوع المتغير؛ فهو يرى `foo()` كاستدعاء دالة، لكنه لا يعلم هل `foo` هي:

- دالة محلية (Local function)
- طريقة في كائن غير متزامن (Async method)
- متغير تم استيراده من حزمة أخرى (Imported symbol)

يقوم خادم اللغة (مثل Dart Analysis Server أو TypeScript Language Server) بحساب الدلالات وإرسال طلب `textDocument/semanticTokens/full` أو `textDocument/semanticTokens/range`.

### 4.2 تنسيق البيانات المضغوط (LSP Semantic Tokens Format)

يرسل السيرفر مصفوفة أرقام صحيحة خماسية مضغوطة نسبياً (Delta-encoded):

```text
[deltaLine, deltaStartChar, length, tokenTypeIndex, tokenModifierBitmask, ...]
```

- كل رمز يُحدد نسبة إلى بداية الرمز السابق لتقليل حجم البيانات المنقولة عبر الشبكة أو الـ IPC.

### 4.3 جدول ترجمة الأنماط (`SemanticTokensProviderStyling`)

يقوم VS Code بترجمة رقم نوع الرمز (`tokenTypeIndex`) وقناع التعديل (`tokenModifierBitmask`) إلى ألوان ثيم:

1. يقرأ السجل `SemanticTokensLegend` (مثلاً: `['class', 'function', 'variable', 'parameter']`).
2. يطابق النوع مع ثيم المحرر عبر:
   `themeService.getColorTheme().getTokenStyleMetadata(tokenType, tokenModifiers, languageId)`
3. يولد قيمة الـ metadata مع تفعيل بتات التحكم:
   `SEMANTIC_USE_FOREGROUND | SEMANTIC_USE_BOLD | SEMANTIC_USE_ITALIC`

---

## 5. محرك الدمج الثنائي للرموز (Token Merging Engine)

هذا هو قلب التناغم بين النحو والدلالة، ويقع في:
`src/vs/editor/common/tokens/sparseTokensStore.ts`

عندما يطلب محرك العرض رموز سطر ما:

```typescript
// في TokenizationTextModelPart.ts
public getLineTokens(lineNumber: number): LineTokens {
    const syntacticTokens = this.tokens.get().getLineTokens(lineNumber);
    return this._semanticTokens.addSparseTokens(lineNumber, syntacticTokens);
}
```

### كيف تتم عملية الدمج الدقيقة؟

الرموز النحوية تغطي كامل السطر (Contiguous)، بينما الرموز الدلالية متفرقة وتغطي فقط الكلمات التي يفهمها السيرفر (Sparse).

تقوم دالة `addSparseTokens` بتمرير مؤشرين (`aIndex` للنحوي، و `bIndex` للدلالي) وتُطبق العملية البتية:

```typescript
// استخراج قناع الخصائص التي حددها الرمز الدلالي فعلياً:
const bMask = (
    ((bMetadata & MetadataConsts.SEMANTIC_USE_ITALIC) ? MetadataConsts.ITALIC_MASK : 0)
    | ((bMetadata & MetadataConsts.SEMANTIC_USE_BOLD) ? MetadataConsts.BOLD_MASK : 0)
    | ((bMetadata & MetadataConsts.SEMANTIC_USE_UNDERLINE) ? MetadataConsts.UNDERLINE_MASK : 0)
    | ((bMetadata & MetadataConsts.SEMANTIC_USE_STRIKETHROUGH) ? MetadataConsts.STRIKETHROUGH_MASK : 0)
    | ((bMetadata & MetadataConsts.SEMANTIC_USE_FOREGROUND) ? MetadataConsts.FOREGROUND_MASK : 0)
    | ((bMetadata & MetadataConsts.SEMANTIC_USE_BACKGROUND) ? MetadataConsts.BACKGROUND_MASK : 0)
) >>> 0;

// قناع الخصائص التي سنحتفظ بها من الرمز النحوي:
const aMask = (~bMask) >>> 0;

// دمج البيانات دون المساس بخصائص اللغة أو الأقواس:
const mergedMetadata = (aMetadata & aMask) | (bMetadata & bMask);
```

**النتيجة العبقرية:**
إذا حدد TextMate أن الكلمة بالخط المائل، وحدد LSP لوناً دلالياً للمتغير، يتم دمج الاثنين: يأخذ المتغير اللون من LSP والخط المائل من TextMate!

---

## 6. نظام الثيمات وتوليد الـ CSS الديناميكي

يقع في:
`src/vs/editor/common/languages/supports/tokenization.ts` و `src/vs/workbench/services/themes/`

### 6.1 مصفوفة الألوان المجمعة (Color Map)

- يجمع VS Code جميع الألوان المستخدمة في الثيم الحالي في مصفوفة فريدة `ColorMap`.
- كل لون يُمنح فهرساً عددياً يبدأ من 1 (مثلاً: `#569cd6` يأخذ المعرف 1، `#4ec9b0` يأخذ 2).
- يدعم المحرك حتى 512 لوناً مختلفاً لكل ثيم (9 بتات في الـ Metadata).

### 6.2 حقن قواعد الـ CSS الديناميكية

يقوم المحرك بإنشاء وسم `<style>` ديناميكي في صفحة الـ DOM يحتوي على الفئات (Classes) التالية:

```css
/* توليد الفئات في generateTokensCSSForColorMap */
.mtk1 { color: #569cd6; }
.mtk2 { color: #4ec9b0; }
.mtk3 { color: #dcdcaa; }
.mtk4 { color: #ce9178; }

/* قواعد أنماط الخط */
.mtki { font-style: italic; }
.mtkb { font-weight: bold; }
.mtku { text-decoration: underline; text-underline-position: under; }
.mtks { text-decoration: line-through; }
.mtks.mtku { text-decoration: underline line-through; text-underline-position: under; }
```

> **ملاحظة:** الاختصار `mtk` يعني **Monaco Token**.

---

## 7. تلوين أزواج الأقواس (Bracket Pair Colorization)

يقع في:
`src/vs/editor/common/model/bracketPairsTextModelPart/`

- لا يعتمد تلوين الأقواس على محلل النصوص العادي، بل يستخدم شجرة بيانات متوازنة تسمى **2-3 Tree** (`BracketPairsTree`).
- يتم تحديث الشجرة بشكل متزايد (Incremental) فائق السرعة عند كل ضغطة زر.
- يتم تطبيق الألوان عبر مزود الزخارف المضمنة (`ColorizedBracketPairsDecorationProvider`).
- يحسب عمق القوس (`nestingLevel`) ويُطبق عليه ألوان السلسلة:
  `editorBracketHighlightingForeground1` إلى `editorBracketHighlightingForeground6`.
- تُدمج هذه الفئات في مخرجات العرض كـ `LineDecoration` مضمنة تتداخل بسلاسة مع التوكنز.

---

## 8. محرك العرض في الشاشة (View Rendering Engine)

يقع في:
`src/vs/editor/common/viewLayout/viewLineRenderer.ts` و `src/vs/editor/browser/viewParts/viewLines/`

عندما تصبح `LineTokens` جاهزة للسطر، تقوم دالة `renderViewLine` بتحويلها إلى DOM String عبر خوارزمية عالية الأداء:

1. **التقسيم والقص (`transformAndRemoveOverflowing`):**
   - تحويل الرموز الثنائية إلى كائنات `LinePart`.
   - استخراج اسم الفئة عبر `TokenMetadata.getClassNameFromMetadata(metadata)` لتصبح مثلاً `"mtk3 mtki"`.
   - عزل نصوص اللغات ثنائية الاتجاه (RTL/Bidi) مثل النصوص العربية عبر `unicode-bidi: isolate`.
2. **معالجة المسافات البيضاء والتابات:**
   - استبدال المسافات التلقائية برموز خاصة مثل `mtkw` مع تحديد عرضها الدقيق بوحدة البيكسل.
3. **توليد الـ HTML باستخدام `StringBuilder`:**
   - يولد المحرر سطراً بصيغة HTML نظيفة ومجمعة:

     ```html
     <span>
       <span class="mtk6">function</span>
       <span class="mtk1"> </span>
       <span class="mtk9 mtki">calculateTotal</span>
       <span class="bracket0">(</span>
       <span class="mtk4">price</span>
       <span class="bracket0">)</span>
     </span>
     ```

4. **المحرك الرسومي الحديث (Experimental GPU Rendering):**
   - في المجلد `src/vs/editor/browser/viewParts/viewLinesGpu/`، يمتلك VS Code حالياً محرك تجارب مبني على **WebGL/WebGPU**.
   - بدلاً من إنشاء عناصر DOM لكل رمز، يتم رفع الـ Glyphs كـ Texture Atlas على كرت الشاشة ورسم النصوص بالكامل بواسطة الشيدرز (Shaders) للوصول إلى 120fps حتى في الملفات العملاقة.

---

## 9. الدروس المستفادة لمشروعنا (Flutter Code Editor)

عند بناء محرر أكواد عالي الأداء في **Flutter** (كما في مشروعنا الحالي `lib/core/` و `lib/parts/editor/`)، هناك مبادئ معمارية ذهبية يمكننا استيرادها مباشرة من VS Code:

| المفهوم في VS Code | التطبيق المقابل في Flutter Code Editor |
| --- | --- |
| **الترميز الثنائي 32-bit** | تجنب إنشاء كائنات `TextSpan` لكل توكن نحوي وتخزينها في الذاكرة. استخدام مصفوفات أعداد صحيحة `Int32List` لتمثيل التوكنز في السطر: `[endOffset, styleId]`. |
| **التلوين على مرحلتين (Two Layers)** | **المرحلة 1:** تلوين نحوي فوري وسريع (باستخدام Regex محلي أو Treesitter/Highlight.dart) يغطي السطور المرئية.<br>**المرحلة 2:** التلوين الدلالي عبر LSP؛ حيث يستقبل `SemanticTokens` في الخلفية ويقوم بعمل Bitmask overlay على الستايل الحالي دون إعادة تحليل النص بالكامل. |
| **تقسيم العمليات بالـ Viewport** | لا تقم بتلوين ملف من 10,000 سطر دفعة واحدة! قم فقط بتلوين الأسطر الواقعة بين `firstVisibleLine` و `lastVisibleLine` داخل `CustomPainter` أو `ListView.builder`. |
| **عزل تلوين الأقواس** | معالجة أزواج الأقواس بنظام تتبع المستويات (Nesting stack) كطبقة إضافية مستقلة عن قواعد التلوين الأساسية. |
| **الحد من كائنات الـ GC** | استخدام نمط التخزين المؤقت للأنماط (`TextStyle Cache` / `Color Palette Cache`) بحيث يتم تعيين `TextStyle` من مصفوفة جاهزة بدلاً من استدعاء `TextStyle(...)` في كل إطار رسم. |

---

## 10. خريطة الملفات المرجعية في VS Code Main

للمراجعة والتعمق المباشر في كود VS Code المصدري:

- **الترميز الثنائي للألوان والسمات:**
  `vscode-main/src/vs/editor/common/encodedTokenAttributes.ts`
- **محرك تلوين TextMate:**
  `vscode-main/src/vs/workbench/services/textMate/browser/tokenizationSupport/textMateTokenizationSupport.ts`
- **العامل في الخلفية (Async Web Worker Tokenizer):**
  `vscode-main/src/vs/workbench/services/textMate/browser/backgroundTokenization/textMateWorkerTokenizerController.ts`
- **التلوين الدلالي (Semantic Tokens Provider):**
  `vscode-main/src/vs/editor/contrib/semanticTokens/browser/documentSemanticTokens.ts`
- **محرك دمج التوكنز النحوية والدلالية:**
  `vscode-main/src/vs/editor/common/tokens/sparseTokensStore.ts`
- **توليد أكواد الـ CSS للثيمات:**
  `vscode-main/src/vs/editor/common/languages/supports/tokenization.ts`
- **تلوين الأقواس المتداخلة (Bracket Pairs):**
  `vscode-main/src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsImpl.ts`
- **محرك توليد الـ HTML للشاشة:**
  `vscode-main/src/vs/editor/common/viewLayout/viewLineRenderer.ts`
- **محرك العرض التجريبي على كرت الشاشة (GPU Renderer):**
  `vscode-main/src/vs/editor/browser/viewParts/viewLinesGpu/`
