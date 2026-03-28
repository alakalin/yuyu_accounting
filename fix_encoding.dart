import 'dart:io';

void main() {
  var dir = Directory('lib');
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        var bytes = entity.readAsBytesSync();
        try {
          String.fromCharCodes(bytes);
        } catch (_) {}
      } catch (e) {}
    }
  }
}
