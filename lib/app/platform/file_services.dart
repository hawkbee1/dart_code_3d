import 'dart:typed_data';

import 'package:dart_code_3d/app/platform/platform_capabilities.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// A file the user picked: its [name] and content.
class PickedFile extends Equatable {
  /// Creates a picked file.
  const new({required this.name, required this.bytes});

  /// The name, with its extension.
  final String name;

  /// The content.
  final Uint8List bytes;

  @override
  List<Object?> get props => [name, bytes];
}

/// The dialogs that pick what to analyze or open. Every method returns
/// null when the user cancels.
abstract interface class FileDialogs {
  /// A `.dc3d` or `.fscene` code map.
  Future<PickedFile?> pickCodeMap();

  /// A zip file of source code.
  Future<PickedFile?> pickZip();

  /// A folder, as an absolute path (not on the web).
  Future<String?> pickFolder();
}

/// Hands a file over to the user.
abstract interface class FileExporter {
  /// Shares, saves or downloads [bytes] as [fileName], as [mode] says.
  Future<void> export({
    required String fileName,
    required Uint8List bytes,
    required ExportMode mode,
  });
}

/// [FileDialogs] over the platform's native pickers (`file_picker`).
class FilePickerDialogs implements FileDialogs {
  /// Creates the dialogs.
  const new();

  @override
  Future<PickedFile?> pickCodeMap() => _pick(const ['dc3d', 'fscene']);

  @override
  Future<PickedFile?> pickZip() => _pick(const ['zip']);

  @override
  Future<String?> pickFolder() => FilePicker.getDirectoryPath();

  Future<PickedFile?> _pick(List<String> extensions) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }
}

/// [FileExporter] over `share_plus` (the share sheet) and `file_picker` (a
/// save dialog on desktop, a download on the web).
class PlatformFileExporter implements FileExporter {
  /// Creates the exporter; [sharePlus] is injectable for tests.
  new({SharePlus? sharePlus}) : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  static const _mimeType = 'application/octet-stream';

  @override
  Future<void> export({
    required String fileName,
    required Uint8List bytes,
    required ExportMode mode,
  }) async {
    switch (mode) {
      case ExportMode.share:
        await _sharePlus.share(
          ShareParams(
            title: fileName,
            files: [XFile.fromData(bytes, name: fileName, mimeType: _mimeType)],
            fileNameOverrides: [fileName],
          ),
        );
      case ExportMode.saveFile || ExportMode.download:
        await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    }
  }
}
