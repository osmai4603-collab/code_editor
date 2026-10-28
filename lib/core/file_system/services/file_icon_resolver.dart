import 'package:flutter/material.dart';

class FileIconResolver {
  static ({IconData icon, Color color}) resolveFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.dart')) {
      return (icon: Icons.flutter_dash, color: const Color(0xFF40C4FF));
    }
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
      return (icon: Icons.settings, color: const Color(0xFFCB3837));
    }
    if (lower.endsWith('.md')) {
      return (icon: Icons.menu_book, color: const Color(0xFF42A5F5));
    }
    if (lower.endsWith('.json')) {
      return (icon: Icons.data_object, color: const Color(0xFFFBC02D));
    }
    if (lower.endsWith('.py')) {
      return (icon: Icons.code, color: const Color(0xFF4B8BBE));
    }
    if (lower.endsWith('.js') || lower.endsWith('.ts')) {
      return (icon: Icons.javascript, color: const Color(0xFFF0DB4F));
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return (icon: Icons.html, color: const Color(0xFFE44D26));
    }
    if (lower.endsWith('.css')) {
      return (icon: Icons.palette_outlined, color: const Color(0xFF42A5F5));
    }
    if (lower == 'dockerfile' || lower == 'makefile') {
      return (icon: Icons.build_outlined, color: const Color(0xFF9E9E9E));
    }
    if (lower == '.gitignore' || lower == '.editorconfig') {
      return (icon: Icons.settings_outlined, color: const Color(0xFF9E9E9E));
    }
    return (
      icon: Icons.insert_drive_file_outlined,
      color: const Color(0xFF9E9E9E),
    );
  }

  static ({IconData icon, Color color}) resolveFolderIcon(
    String folderName, {
    bool isExpanded = false,
  }) {
    const specialColors = {
      'lib': Color(0xFF40C4FF),
      'test': Color(0xFF4CAF50),
      '.git': Color(0xFFF05032),
      'build': Color(0xFF9E9E9E),
      'assets': Color(0xFFCE93D8),
    };
    return (
      icon: isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
      color: specialColors[folderName] ?? const Color(0xFFDCA857),
    );
  }
}
