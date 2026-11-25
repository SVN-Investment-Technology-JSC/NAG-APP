import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/vehicle_detail_sheet_v2.dart';
import 'package:nguyenanh/features/home/presentation/widgets/vehicle_detail_sheet.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';

/// Opens the vehicle detail sheet in the UI chosen by the "Giao diện mới" switch.
/// Used by widgets shared by the v1 and v2 screens (e.g. the home map section).
void showVehicleDetailSheet(BuildContext context, VtrackingVehicle v, List<Station> stations) {
  final newUi = context.read<UiVersionProvider>().isNewUi;
  if (newUi) {
    VehicleDetailSheetV2.show(context, v, stations);
  } else {
    VehicleDetailSheet.show(context, v, stations);
  }
}
