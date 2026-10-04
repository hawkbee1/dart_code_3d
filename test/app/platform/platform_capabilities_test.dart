import 'package:dart_code_3d/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PlatformCapabilities, () {
    test('desktop runs everything and saves with a dialog', () {
      expect(PlatformCapabilities.desktop.gitSources, isTrue);
      expect(PlatformCapabilities.desktop.folderSources, isTrue);
      expect(PlatformCapabilities.desktop.persistentStorage, isTrue);
      expect(PlatformCapabilities.desktop.exportMode, ExportMode.saveFile);
    });

    test('mobile has no folders and shares', () {
      expect(PlatformCapabilities.mobile.gitSources, isTrue);
      expect(PlatformCapabilities.mobile.folderSources, isFalse);
      expect(PlatformCapabilities.mobile.persistentStorage, isTrue);
      expect(PlatformCapabilities.mobile.exportMode, ExportMode.share);
    });

    test('web has no git, no folders and no storage, and downloads', () {
      expect(PlatformCapabilities.web.gitSources, isFalse);
      expect(PlatformCapabilities.web.folderSources, isFalse);
      expect(PlatformCapabilities.web.persistentStorage, isFalse);
      expect(PlatformCapabilities.web.exportMode, ExportMode.download);
    });

    test('compares by value', () {
      // Not constants, so this really is another instance.
      var off = false;
      final same = PlatformCapabilities(
        gitSources: off,
        folderSources: off,
        persistentStorage: off,
        exportMode: ExportMode.download,
      );
      off = true;

      expect(same, PlatformCapabilities.web);
      expect(PlatformCapabilities.web, isNot(PlatformCapabilities.mobile));
    });

    group('current', () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final (platform, expected) in [
        (TargetPlatform.android, PlatformCapabilities.mobile),
        (TargetPlatform.iOS, PlatformCapabilities.mobile),
        (TargetPlatform.linux, PlatformCapabilities.desktop),
        (TargetPlatform.macOS, PlatformCapabilities.desktop),
        (TargetPlatform.windows, PlatformCapabilities.desktop),
        (TargetPlatform.fuchsia, PlatformCapabilities.desktop),
      ]) {
        test('is what $platform can do', () {
          debugDefaultTargetPlatformOverride = platform;

          expect(PlatformCapabilities.current, expected);
        });
      }
    });
  });
}
