import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StatusBarPreferencesStore {
  Future<Set<String>> readHiddenEntryIds();

  Future<void> writeHiddenEntryIds(Set<String> ids);
}

class SharedPreferencesStatusBarPreferencesStore
    implements StatusBarPreferencesStore {
  static const _hiddenEntryIdsKey = 'status_bar.hidden_entry_ids';

  @override
  Future<Set<String>> readHiddenEntryIds() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(_hiddenEntryIdsKey);
    if (value == null) return <String>{};
    if (value is List && value.every((id) => id is String)) {
      return value.cast<String>().where((id) => id.isNotEmpty).toSet();
    }
    throw FormatException('Invalid status bar preferences value');
  }

  @override
  Future<void> writeHiddenEntryIds(Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setStringList(
      _hiddenEntryIdsKey,
      ids.toList()..sort(),
    );
    if (!saved) {
      throw StateError('Unable to save status bar visibility preferences');
    }
  }
}

class InMemoryStatusBarPreferencesStore implements StatusBarPreferencesStore {
  Set<String> _hiddenEntryIds;

  InMemoryStatusBarPreferencesStore({
    Set<String> hiddenEntryIds = const {},
  }) : _hiddenEntryIds = Set.of(hiddenEntryIds);

  @override
  Future<Set<String>> readHiddenEntryIds() async =>
      Set.unmodifiable(_hiddenEntryIds);

  @override
  Future<void> writeHiddenEntryIds(Set<String> ids) async {
    _hiddenEntryIds = Set.of(ids);
  }
}
