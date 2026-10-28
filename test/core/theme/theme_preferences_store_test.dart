import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/theme/theme_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared preferences store persists selected theme id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesThemePreferencesStore();

    expect(await store.readThemeId(), isNull);
    await store.writeThemeId('light-modern');
    expect(await store.readThemeId(), 'light-modern');
  });

  test('shared preferences store rejects a value of the wrong type', () async {
    SharedPreferences.setMockInitialValues({'appearance.color_theme': 42});
    final store = SharedPreferencesThemePreferencesStore();

    await expectLater(store.readThemeId(), throwsFormatException);
  });

  test('in-memory store reads and writes selected theme id', () async {
    final store = InMemoryThemePreferencesStore();

    expect(await store.readThemeId(), isNull);
    await store.writeThemeId('light-modern');
    expect(await store.readThemeId(), 'light-modern');
  });

  test('in-memory store rejects an empty theme id', () async {
    final store = InMemoryThemePreferencesStore();

    await expectLater(store.writeThemeId(''), throwsArgumentError);
  });
}
