import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/features/setup/presentation/v2/selection_page_v2.dart';

/// Login screen entry: the redesigned [SelectionPageV2] or the original [SelectionPage],
/// following the app-wide "Giao diện mới" switch ([UiVersionProvider]).
class SelectionEntry extends StatelessWidget {
  const SelectionEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final newUi = context.watch<UiVersionProvider>().isNewUi;
    return newUi ? const SelectionPageV2() : const SelectionPage();
  }
}
