import 'dart:io';

void main() async {
  final directory = Directory('lib');
  if (!await directory.exists()) {
    print('lib directory not found.');
    return;
  }

  int count = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      if (content.contains('package:vehicle_management')) {
        final newContent = content.replaceAll('package:vehicle_management', 'package:nguyenanh');
        await entity.writeAsString(newContent);
        count++;
      }
    }
  }

  final pubspec = File('pubspec.yaml');
  if (await pubspec.exists()) {
    final content = await pubspec.readAsString();
    final newContent = content.replaceFirst('name: vehicle_management', 'name: nguyenanh');
    await pubspec.writeAsString(newContent);
    print('Updated pubspec.yaml');
  }

  print('Successfully renamed package in \$count files.');
}
