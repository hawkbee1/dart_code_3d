import 'dart:io';
import 'dart:typed_data';

/// Reads the local file at [path].
Future<Uint8List> readLocalFile(String path) => File(path).readAsBytes();
