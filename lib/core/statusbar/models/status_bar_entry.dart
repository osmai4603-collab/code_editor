import 'package:flutter/material.dart';

import 'status_bar_alignment.dart';
import 'status_bar_entry_kind.dart';

@immutable
class StatusBarEntry {
  final String id;
  final String name;
  final String text;
  final StatusBarAlignment alignment;
  final int priority;
  final String? tooltip;
  final String? ariaLabel;
  final StatusBarEntryKind kind;
  final IconData? icon;
  final VoidCallback? onPressed;

  const StatusBarEntry({
    required this.id,
    required this.name,
    required this.text,
    required this.alignment,
    required this.priority,
    this.tooltip,
    this.ariaLabel,
    this.kind = StatusBarEntryKind.standard,
    this.icon,
    this.onPressed,
  }) : assert(id != ''), assert(name != '');

  StatusBarEntry copyWith({
    String? id,
    String? name,
    String? text,
    StatusBarAlignment? alignment,
    int? priority,
    String? tooltip,
    String? ariaLabel,
    StatusBarEntryKind? kind,
    IconData? icon,
    VoidCallback? onPressed,
    bool clearTooltip = false,
    bool clearAriaLabel = false,
    bool clearIcon = false,
    bool clearOnPressed = false,
  }) {
    return StatusBarEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      text: text ?? this.text,
      alignment: alignment ?? this.alignment,
      priority: priority ?? this.priority,
      tooltip: clearTooltip ? null : tooltip ?? this.tooltip,
      ariaLabel: clearAriaLabel ? null : ariaLabel ?? this.ariaLabel,
      kind: kind ?? this.kind,
      icon: clearIcon ? null : icon ?? this.icon,
      onPressed: clearOnPressed ? null : onPressed ?? this.onPressed,
    );
  }
}
