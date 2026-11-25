import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/pages/fleet_monitoring_page.dart' as v1;
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/pages/fx_monitoring_page.dart' as v2;

/// Entry point of "Giám sát xe".
///
/// Two UIs live side by side so the new one can be rolled back:
///   * v1 — the first version (presentation/v1), kept untouched.
///   * v2 — the redesigned UI (presentation/v2).
/// Both share the same data layer, permissions and analysis logic (data/, fleet_utils.dart, fuel_analysis.dart).
///
/// Which one is shown follows the app-wide "Giao diện mới" switch ([UiVersionProvider]).
class FleetMonitoringEntry extends StatelessWidget {
  final FleetPermissions? perms;

  const FleetMonitoringEntry({super.key, this.perms});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiVersionProvider>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ui.isNewUi
          ? v2.FxMonitoringPage(key: const ValueKey('v2'), perms: perms, onSwitchUi: () => ui.setNewUi(false))
          : v1.FleetMonitoringPage(key: const ValueKey('v1'), perms: perms, onSwitchUi: () => ui.setNewUi(true)),
    );
  }
}
