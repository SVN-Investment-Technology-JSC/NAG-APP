import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/application_form/data/models/application_model.dart';
import 'package:nguyenanh/features/application_form/data/services/application_service.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class ApplicationProvider extends ChangeNotifier {
  final ApplicationService _service = ApplicationService(ApiClient.dio);

  List<LotTagRequest> _requests = [];
  int _totalRequests = 0;
  bool _isLoading = false;

  List<LotTagCatalogItem> _lotTags = [];
  List<WorkVehicle> _vehicles = [];
  bool _isCatalogLoading = false;

  List<LotTagRequest> get requests => _requests;
  int get totalRequests => _totalRequests;
  bool get isLoading => _isLoading;

  List<LotTagCatalogItem> get lotTags => _lotTags;
  List<WorkVehicle> get vehicles => _vehicles;
  bool get isCatalogLoading => _isCatalogLoading;

  Future<void> fetchRequests({
    required int page,
    required int limit,
    required String status,
    String? workDate,
    required bool mine,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.listRequests(
        page: page,
        limit: limit,
        status: status,
        workDate: workDate,
        mine: mine,
      );
      _requests = result['requests'];
      _totalRequests = result['total'];
    } catch (e) {
      _requests = [];
      _totalRequests = 0;
      debugPrint('[API] Error loading requests: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCatalog() async {
    _isCatalogLoading = true;
    notifyListeners();

    try {
      final tags = await _service.listLotTags();
      final vehiclesList = await _service.listVehicles();
      _lotTags = tags;
      _vehicles = vehiclesList;
    } catch (e) {
      debugPrint('[API] Error loading catalogs: $e');
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest({
    required String workDate,
    required int vehicleId,
    required int? lotTagId,
    required String lotTagKey,
    String? requestReason,
  }) async {
    await _service.createRequest(
      workDate: workDate,
      vehicleId: vehicleId,
      lotTagId: lotTagId,
      lotTagKey: lotTagKey,
      requestReason: requestReason,
    );
  }

  Future<void> approveRequest(int requestId, String? note) async {
    final updated = await _service.approveRequest(requestId, note);
    _updateRequestInList(updated);
  }

  Future<void> rejectRequest(int requestId, String reason) async {
    final updated = await _service.rejectRequest(requestId, reason);
    _updateRequestInList(updated);
  }

  Future<void> cancelRequest(int requestId, String reason) async {
    final updated = await _service.cancelRequest(requestId, reason);
    _updateRequestInList(updated);
  }

  void _updateRequestInList(LotTagRequest updated) {
    final index = _requests.indexWhere((app) => app.lotTagRequestId == updated.lotTagRequestId);
    if (index != -1) {
      _requests[index] = updated;
      notifyListeners();
    }
  }
}
