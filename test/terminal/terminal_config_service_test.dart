import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/terminal/services/terminal_config_service.dart';

void main() {
  test('uses JetBrains Mono with tighter letter spacing by default', () {
    final config = TerminalConfigService();

    expect(config.fontFamily, 'JetBrains Mono');
    expect(config.letterSpacing, -0.2);
  });
}
