import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/syntax/theme/editor_token_theme.dart';
import 'package:code_editor/core/syntax/theme/token_color_palette.dart';
import 'package:code_editor/core/theme/app_theme.dart';
import 'package:code_editor/core/theme/app_theme_data.dart';
import 'package:code_editor/core/theme/editor_theme.dart';

void main() {
  testWidgets('theme dependents receive the same updated theme bundle', (
    tester,
  ) async {
    var selectedTheme = AppThemeData.darkModern;
    late StateSetter updateParent;
    final alternateTheme = AppThemeData(
      id: 'alternate',
      label: 'Alternate',
      editorTheme: EditorThemeData.darkModern,
      tokenTheme: EditorTokenTheme(
        palette: TokenColorPalette([
          Colors.white,
          Colors.white,
          Colors.red,
        ]),
      ),
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateParent = setState;
          return MaterialApp(
            theme: selectedTheme.materialTheme,
            home: AppTheme(
              theme: selectedTheme,
              child: EditorTheme(
                theme: selectedTheme.editorTheme,
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text(AppTheme.of(context).id),
                        Text(
                          EditorTheme.of(context).editorBackground.toString(),
                        ),
                        Text(
                          AppTheme.of(context)
                              .tokenTheme
                              .getStyle(StandardColorId.keyword, 0)
                              .color
                              .toString(),
                        ),
                        Text(
                          Theme.of(context).colorScheme.primary.toString(),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            updateParent(
                              () => selectedTheme = alternateTheme,
                            );
                          },
                          child: const Text('Change theme'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    expect(find.text('dark-modern'), findsOneWidget);
    expect(find.text(Colors.red.toString()), findsNothing);

    await tester.tap(find.text('Change theme'));
    await tester.pumpAndSettle();

    expect(find.text('alternate'), findsOneWidget);
    expect(find.text(Colors.red.toString()), findsOneWidget);
  });
}
