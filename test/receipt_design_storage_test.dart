import 'dart:io';
import 'dart:typed_data';

import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/services/receipt_design_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakePathProvider fakePathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receipt_logo_test_');
    fakePathProvider = _FakePathProvider()..root = tempDir;
    PathProviderPlatform.instance = fakePathProvider;
    SharedPreferences.setMockInitialValues({});
    ReceiptDesignStorage.invalidateCache();
  });

  tearDown(() async {
    ReceiptDesignStorage.invalidateCache();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveLogoFromPath stores new file and updates config path', () async {
    final source = File('${tempDir.path}/picked.png');
    await source.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

    final saved = await ReceiptDesignStorage.saveLogoFromPath(
      ReceiptDesignConfig.defaults,
      source.path,
    );

    expect(saved.showLogo, isTrue);
    expect(saved.logoFilePath, isNotNull);
    expect(File(saved.logoFilePath!).existsSync(), isTrue);

    ReceiptDesignStorage.invalidateCache();
    final loaded = await ReceiptDesignStorage.reload();
    expect(loaded.logoFilePath, saved.logoFilePath);
  });

  test('saveLogoFromBytes persists without source path', () async {
    final saved = await ReceiptDesignStorage.saveLogoFromBytes(
      ReceiptDesignConfig.defaults,
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
      extension: '.png',
    );
    expect(File(saved.logoFilePath!).existsSync(), isTrue);
  });

  test('replacing logo deletes previous file and uses new path', () async {
    final first = File('${tempDir.path}/first.png');
    await first.writeAsBytes([1, 2, 3]);
    final second = File('${tempDir.path}/second.png');
    await second.writeAsBytes([4, 5, 6]);

    var cfg = await ReceiptDesignStorage.saveLogoFromPath(
      ReceiptDesignConfig.defaults,
      first.path,
    );
    final oldPath = cfg.logoFilePath!;
    expect(File(oldPath).existsSync(), isTrue);

    cfg = await ReceiptDesignStorage.saveLogoFromPath(cfg, second.path);
    expect(cfg.logoFilePath, isNot(oldPath));
    expect(File(cfg.logoFilePath!).existsSync(), isTrue);
    expect(File(oldPath).existsSync(), isFalse);
  });

  test('reload keeps saved custom store title', () async {
    SharedPreferences.setMockInitialValues({
      'receipt_design_config_v1':
          '{"showLogo":true,"storeTitle":"ssssss","useBranchNameAsTitle":false}',
    });
    final loaded = await ReceiptDesignStorage.reload();
    expect(loaded.storeTitle, 'ssssss');
    expect(loaded.useBranchNameAsTitle, isFalse);
  });

  test('old showLogo false still installs bundled default logo', () async {
    SharedPreferences.setMockInitialValues({
      'receipt_design_config_v1': '{"showLogo":false}',
    });
    final loaded = await ReceiptDesignStorage.reload();
    expect(loaded.showLogo, isTrue);
    expect(loaded.logoFilePath, isNotNull);
    expect(File(loaded.logoFilePath!).existsSync(), isTrue);
  });

  test('prepareForPrint turns logo on and writes bundled file', () async {
    SharedPreferences.setMockInitialValues({
      'receipt_design_config_v1': '{"showLogo":false}',
    });
    final prepared = await ReceiptDesignStorage.prepareForPrint(null);
    expect(prepared.showLogo, isTrue);
    expect(prepared.logoFilePath, isNotNull);
    expect(File(prepared.logoFilePath!).existsSync(), isTrue);
  });

  test('load seeds bundled Untitled-1-08 as default logo', () async {
    final loaded = await ReceiptDesignStorage.load();
    expect(loaded.showLogo, isTrue);
    expect(loaded.logoFilePath, isNotNull);
    expect(File(loaded.logoFilePath!).existsSync(), isTrue);
    expect(
      File(loaded.logoFilePath!).lengthSync(),
      greaterThan(1000),
    );
  });

  test('removeLogo clears path and deletes file', () async {
    final source = File('${tempDir.path}/logo.png');
    await source.writeAsBytes([9, 9, 9]);

    var cfg = await ReceiptDesignStorage.saveLogoFromPath(
      ReceiptDesignConfig.defaults,
      source.path,
    );
    final path = cfg.logoFilePath!;

    cfg = await ReceiptDesignStorage.removeLogo(cfg);
    await ReceiptDesignStorage.save(cfg);
    expect(cfg.showLogo, isFalse);
    expect(cfg.logoFilePath, isNull);
    expect(File(path).existsSync(), isFalse);

    ReceiptDesignStorage.invalidateCache();
    final after = await ReceiptDesignStorage.reload();
    expect(after.showLogo, isFalse);
  });
}
