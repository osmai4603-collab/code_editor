import 'dart:io';
import 'package:flutter/material.dart';
import '../pty/pty_options.dart';

class TerminalProfile {
  final String name;
  final String executablePath;
  final List<String> args;
  final IconData? icon;
  final Color? color;
  final Map<String, String> environment;

  const TerminalProfile({
    required this.name,
    required this.executablePath,
    this.args = const [],
    this.icon,
    this.color,
    this.environment = const {},
  });

  static Future<List<TerminalProfile>> detectAvailableProfiles() async {
    final shells = Platform.isWindows
        ? [PtyOptions.defaultShell]
        : ['/bin/bash', '/bin/zsh', '/usr/bin/fish', '/bin/sh'];
    final profiles = <TerminalProfile>[];
    for (final shell in shells) {
      if (await File(shell).exists()) {
        profiles.add(
          TerminalProfile(
            name: shell.split(Platform.pathSeparator).last,
            executablePath: shell,
            args: PtyOptions.defaultShellArgs,
            icon: Icons.terminal,
          ),
        );
      }
    }
    return profiles;
  }
}
