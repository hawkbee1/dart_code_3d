import 'dart:typed_data';

/// Local files cannot be read by path in a browser.
Future<Uint8List> readLocalFile(String path) =>
    throw UnsupportedError('Local files cannot be opened by path on the web.');
