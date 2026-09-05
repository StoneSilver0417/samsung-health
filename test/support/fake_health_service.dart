import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/health_service.dart';

class FakeHealthService extends HealthService {
  bool configureCalled = false;
  bool permissionGranted = true;
  bool extraPermissionGranted = true;
  bool historyPermissionGranted = true;
  List<RunSession> runsToReturn = [];
  List<(DateTime, double)> vo2SeriesToReturn = [];
  Object? configureError;
  Object? fetchRunsError;
  DateTime? lastFetchedSince;

  @override
  Future<void> configure() async {
    configureCalled = true;
    if (configureError != null) throw configureError!;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<bool> requestExtraPermissions() async => extraPermissionGranted;

  @override
  Future<bool> requestHistoryPermission() async => historyPermissionGranted;

  @override
  Future<List<RunSession>> fetchRuns({DateTime? since}) async {
    lastFetchedSince = since;
    if (fetchRunsError != null) throw fetchRunsError!;
    return List.of(runsToReturn);
  }

  @override
  Future<List<(DateTime, double)>> fetchVo2Series(
      DateTime start, DateTime end) async {
    return List.of(vo2SeriesToReturn);
  }
}
