import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/utils/receipt_store_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API branch name is used when toggle is on', () {
    final design = ReceiptDesignConfig.defaults.copyWith(
      storeTitle: 'ssssss',
      useBranchNameAsTitle: true,
    );
    expect(
      ReceiptStoreTitle.resolve(
        design: design,
        branchName: 'GULISTON YEMLARI - Asosiy filial',
      ),
      'GULISTON YEMLARI - Asosiy filial',
    );
  });

  test('custom store title is used when toggle is off', () {
    final design = ReceiptDesignConfig.defaults.copyWith(
      storeTitle: 'ssssss',
      useBranchNameAsTitle: false,
    );
    expect(
      ReceiptStoreTitle.resolve(
        design: design,
        branchName: 'GULISTON YEMLARI - Asosiy filial',
      ),
      'ssssss',
    );
  });

  test('empty title when no custom or branch — no Alfa market fallback', () {
    final design = ReceiptDesignConfig.defaults.copyWith(
      storeTitle: '',
      useBranchNameAsTitle: false,
    );
    expect(
      ReceiptStoreTitle.resolve(design: design, branchName: ''),
      isEmpty,
    );
  });

  test('Alfa market placeholder is ignored', () {
    final design = ReceiptDesignConfig.defaults.copyWith(
      storeTitle: 'Alfa market',
      useBranchNameAsTitle: false,
    );
    expect(
      ReceiptStoreTitle.resolve(design: design, branchName: ''),
      isEmpty,
    );
  });

  test('standardFrom drops custom store title and keeps logo', () {
    final saved = ReceiptDesignConfig.defaults.copyWith(
      storeTitle: 'ssssss',
      logoFilePath: '/tmp/logo.png',
      showLogo: true,
    );
    final std = ReceiptDesignConfig.standardFrom(saved);
    expect(std.storeTitle, isEmpty);
    expect(std.useBranchNameAsTitle, isTrue);
    expect(std.logoFilePath, '/tmp/logo.png');
    expect(std.showLogo, isTrue);
  });
}
