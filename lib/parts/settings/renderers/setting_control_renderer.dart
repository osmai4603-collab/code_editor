import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/configuration/contracts/configuration_inspect_result.dart';
import '../../../core/configuration/contracts/setting_value_type.dart';
import '../../../core/configuration/registry/setting_definition.dart';

class SettingControlRenderer {
  static Widget build({
    required SettingDefinition<Object?> setting,
    required ConfigurationInspectResult<Object?> inspectResult,
    required ValueChanged<Object?> onChanged,
  }) {
    return switch (setting.type) {
      SettingValueType.boolean => Switch(
        value: inspectResult.effectiveValue as bool,
        activeThumbColor: const Color(0xff0078d4),
        onChanged: onChanged,
      ),
      SettingValueType.integer => _DebouncedNumberField(
        key: ValueKey(setting.key),
        value: inspectResult.effectiveValue as num,
        onChanged: onChanged,
      ),
      SettingValueType.doubleNumber => _DebouncedNumberField(
        key: ValueKey(setting.key),
        value: inspectResult.effectiveValue as num,
        decimal: true,
        onChanged: onChanged,
      ),
      SettingValueType.enumeration => DropdownButton<String>(
        value:
            setting.options.any(
              (option) => option.value == inspectResult.effectiveValue,
            )
            ? inspectResult.effectiveValue as String
            : setting.options.first.value,
        dropdownColor: const Color(0xff252526),
        items: [
          for (final option in setting.options)
            DropdownMenuItem(
              value: option.value,
              child: Tooltip(
                message: option.description,
                child: Text(option.label),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
      SettingValueType.string ||
      SettingValueType.multilineString => _DebouncedTextField(
        key: ValueKey(setting.key),
        value: inspectResult.effectiveValue as String? ?? '',
        multiline: setting.type == SettingValueType.multilineString,
        onChanged: onChanged,
      ),
      SettingValueType.stringList => _StringListControl(
        value: (inspectResult.effectiveValue as List).cast<String>(),
        onChanged: onChanged,
      ),
      SettingValueType.stringMap ||
      SettingValueType.excludePatterns => _ExcludePatternsControl(
        value: Map<String, Object?>.from(inspectResult.effectiveValue as Map),
        onChanged: onChanged,
      ),
      SettingValueType.complex => const Text(
        'Edit this value in settings.json',
      ),
    };
  }
}

class _DebouncedTextField extends StatefulWidget {
  final String value;
  final bool multiline;
  final ValueChanged<Object?> onChanged;

  const _DebouncedTextField({
    super.key,
    required this.value,
    required this.multiline,
    required this.onChanged,
  });

  @override
  State<_DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<_DebouncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: TextField(
      controller: _controller,
      minLines: widget.multiline ? 3 : 1,
      maxLines: widget.multiline ? 6 : 1,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Color(0xff3c3c3c),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 800), () {
          widget.onChanged(value);
        });
      },
    ),
  );
}

class _DebouncedNumberField extends StatefulWidget {
  final num value;
  final bool decimal;
  final ValueChanged<Object?> onChanged;

  const _DebouncedNumberField({
    super.key,
    required this.value,
    this.decimal = false,
    required this.onChanged,
  });

  @override
  State<_DebouncedNumberField> createState() => _DebouncedNumberFieldState();
}

class _DebouncedNumberFieldState extends State<_DebouncedNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.toString(),
  );
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _DebouncedNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    child: TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Color(0xff3c3c3c),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 800), () {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            widget.onChanged(
              widget.decimal ? parsed.toDouble() : parsed.toInt(),
            );
          }
        });
      },
    ),
  );
}

class _StringListControl extends StatefulWidget {
  final List<String> value;
  final ValueChanged<Object?> onChanged;

  const _StringListControl({required this.value, required this.onChanged});

  @override
  State<_StringListControl> createState() => _StringListControlState();
}

class _StringListControlState extends State<_StringListControl> {
  late List<String> _items = List.of(widget.value);
  final _newItemController = TextEditingController();

  @override
  void didUpdateWidget(covariant _StringListControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _items = List.of(widget.value);
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _items.length; index++)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('setting-list-$index-${_items[index]}'),
                  initialValue: _items[index],
                  onChanged: (value) {
                    _items[index] = value;
                    widget.onChanged(List<String>.of(_items));
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () {
                  setState(() => _items.removeAt(index));
                  widget.onChanged(List<String>.of(_items));
                },
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: index == 0
                    ? null
                    : () {
                        setState(() {
                          final item = _items.removeAt(index);
                          _items.insert(index - 1, item);
                        });
                        widget.onChanged(List<String>.of(_items));
                      },
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(child: TextField(controller: _newItemController)),
            IconButton(
              tooltip: 'Add',
              onPressed: () {
                final value = _newItemController.text.trim();
                if (value.isEmpty) return;
                setState(() {
                  _items.add(value);
                  _newItemController.clear();
                });
                widget.onChanged(List<String>.of(_items));
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ExcludePatternsControl extends StatefulWidget {
  final Map<String, Object?> value;
  final ValueChanged<Object?> onChanged;

  const _ExcludePatternsControl({required this.value, required this.onChanged});

  @override
  State<_ExcludePatternsControl> createState() =>
      _ExcludePatternsControlState();
}

class _ExcludePatternsControlState extends State<_ExcludePatternsControl> {
  late Map<String, Object?> _patterns = Map.of(widget.value);
  final _newPatternController = TextEditingController();

  @override
  void didUpdateWidget(covariant _ExcludePatternsControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _patterns = Map.of(widget.value);
  }

  @override
  void dispose() {
    _newPatternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: Column(
      children: [
        for (final entry in _patterns.entries)
          Row(
            children: [
              Checkbox(
                value: entry.value == true,
                onChanged: (value) => _update(entry.key, value ?? false),
              ),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontFamily: 'JetBrains Mono'),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () {
                  setState(() => _patterns.remove(entry.key));
                  widget.onChanged(Map<String, Object?>.of(_patterns));
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(child: TextField(controller: _newPatternController)),
            IconButton(
              tooltip: 'Add pattern',
              onPressed: () {
                final pattern = _newPatternController.text.trim();
                if (pattern.isEmpty) return;
                _update(pattern, true);
                _newPatternController.clear();
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );

  void _update(String key, bool value) {
    setState(() => _patterns[key] = value);
    widget.onChanged(Map<String, Object?>.of(_patterns));
  }
}
