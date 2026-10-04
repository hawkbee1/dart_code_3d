import 'dart:typed_data';

import 'package:dart_code_3d/app/app.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// A picker platform that answers what a test sets and remembers the calls.
class _FakePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  PlatformFile? file;
  String? directory;
  FileType? pickedType;
  List<String>? pickedExtensions;
  ({String fileName, Uint8List bytes})? saved;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickedType = type;
    pickedExtensions = allowedExtensions;
    return file;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => directory;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved = (fileName: fileName, bytes: bytes);
    return null;
  }
}

base class _FakeFile extends PlatformFile {
  new(this.name, this._bytes);

  @override
  final String name;
  final Uint8List _bytes;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Uri get uri => Uri.parse('file:///tmp/$name');

  @override
  XFile get xFile => XFile.fromData(_bytes, name: name);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? shared;

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared = params;
    return ShareResult.unavailable;
  }
}

void main() {
  group(FilePickerDialogs, () {
    late _FakePicker picker;
    late FilePickerPlatform previous;

    setUp(() {
      previous = FilePickerPlatform.instance;
      picker = _FakePicker();
      FilePickerPlatform.instance = picker;
    });

    tearDown(() => FilePickerPlatform.instance = previous);

    test('picks a code map by its extensions, with its bytes', () async {
      picker.file = _FakeFile('AltMe.dc3d', Uint8List.fromList([1, 2, 3]));

      final file = await const FilePickerDialogs().pickCodeMap();

      expect(
        file,
        PickedFile(name: 'AltMe.dc3d', bytes: Uint8List.fromList([1, 2, 3])),
      );
      expect(picker.pickedType, FileType.custom);
      expect(picker.pickedExtensions, ['dc3d', 'fscene']);
    });

    test('picks a zip by its extension', () async {
      picker.file = _FakeFile('app.zip', Uint8List(2));

      final file = await const FilePickerDialogs().pickZip();

      expect(file?.name, 'app.zip');
      expect(picker.pickedExtensions, ['zip']);
    });

    test('returns nothing when the user cancels', () async {
      expect(await const FilePickerDialogs().pickCodeMap(), isNull);
      expect(await const FilePickerDialogs().pickZip(), isNull);
    });

    test('picks a folder path', () async {
      picker.directory = '/home/dev/app';

      expect(await const FilePickerDialogs().pickFolder(), '/home/dev/app');
    });

    test('returns nothing when no folder is chosen', () async {
      expect(await const FilePickerDialogs().pickFolder(), isNull);
    });
  });

  group(PlatformFileExporter, () {
    late _FakeShare share;
    late _FakePicker picker;
    late FilePickerPlatform previous;
    late PlatformFileExporter exporter;
    final bytes = Uint8List.fromList([9, 8, 7]);

    setUp(() {
      share = _FakeShare();
      previous = FilePickerPlatform.instance;
      picker = _FakePicker();
      FilePickerPlatform.instance = picker;
      exporter = PlatformFileExporter(sharePlus: SharePlus.custom(share));
    });

    tearDown(() => FilePickerPlatform.instance = previous);

    test('shares the file under its name in share mode', () async {
      await exporter.export(
        fileName: 'AltMe.dc3d',
        bytes: bytes,
        mode: ExportMode.share,
      );

      final params = share.shared!;
      expect(params.fileNameOverrides, ['AltMe.dc3d']);
      expect(await params.files!.single.readAsBytes(), bytes);
      expect(picker.saved, isNull);
    });

    for (final mode in [ExportMode.saveFile, ExportMode.download]) {
      test('saves the file with a dialog in $mode', () async {
        await exporter.export(fileName: 'AltMe.dc3d', bytes: bytes, mode: mode);

        expect(picker.saved, (fileName: 'AltMe.dc3d', bytes: bytes));
        expect(share.shared, isNull);
      });
    }

    test('uses the shared instance by default', () {
      expect(PlatformFileExporter.new, returnsNormally);
    });
  });
}
