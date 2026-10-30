/// Core contract for opening or validating a file without depending on UI types.
abstract interface class EditorFileOpener {
  Future<void> openFile(
    String path, {
    int? line,
    int? column,
    bool isPreview = false,
  });

  Future<bool> canOpenFile(String path);
}
