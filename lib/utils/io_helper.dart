import 'dart:io';

/// Desktop platform: real directory listing
class _IoDir {
  final Directory _dir;
  _IoDir(String path) : _dir = Directory(path);

  Stream<FileSystemEntity> list({bool recursive = false}) =>
      _dir.list(recursive: recursive, followLinks: false);
}

Stream<String> listDirectory(String dirPath) async* {
  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      yield entity.path;
    }
  } catch (_) {}
}
