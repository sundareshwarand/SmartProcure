import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_procure/core/auth/auth_service.dart';
import 'package:smart_procure/core/repositories/repository.dart';
import 'package:smart_procure/features/auth/auth_providers.dart';
import 'package:smart_procure/features/operator/operator_guard.dart';
import 'package:smart_procure/features/operator/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RBAC & Audit Tests', () {
    late Repository repo;

    setUp(() async {
      repo = Repository(mode: RepositoryMode.mock);
      await AuthService.clearToken();
    });

    test('operator actions create audit logs', () async {
      // set valid operator token with centre C1
      final payload = {'sub': 'op1', 'role': 'operator', 'centre_ids': ['C1'], 'exp': DateTime.now().toUtc().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000};
      final token = 'hdr.' + base64Url.encode(utf8.encode(json.encode(payload))) + '.sig';
      await AuthService.setToken(token);

      final ok1 = await repo.operatorCallNext('Q100');
      expect(ok1, true);
      final ok2 = await repo.operatorStartProcessing('Q100');
      expect(ok2, true);
      final ok3 = await repo.operatorPostQualityCheck('Q100', {'moisture': 10});
      expect(ok3, true);
      final ok4 = await repo.operatorPostWeigh('Q100', {'actual': 100});
      expect(ok4, true);
      final ok5 = await repo.operatorComplete('Q100');
      expect(ok5, true);

      final logs = repo.getMockAuditLogs();
      expect(logs.isNotEmpty, true);
      final actions = logs.map((l) => l['action']).toList();
      expect(actions, containsAll(['CALL_FARMER','START_PROCESSING','QUALITY_CHECK','WEIGHING','COMPLETE_PROCUREMENT']));
    });

    test('expired token detected', () async {
      final payload = {'sub': 'op1', 'role': 'operator', 'centre_ids': ['C1'], 'exp': DateTime.now().toUtc().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000};
      final token = 'hdr.' + base64Url.encode(utf8.encode(json.encode(payload))) + '.sig';
      await AuthService.setToken(token);
      final expired = await AuthService.isTokenExpired();
      expect(expired, true);
    });

    test('concurrent start processing rejected', () async {
      final payload = {'sub': 'op1', 'role': 'operator', 'centre_ids': ['C1'], 'exp': DateTime.now().toUtc().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000};
      final token = 'hdr.' + base64Url.encode(utf8.encode(json.encode(payload))) + '.sig';
      await AuthService.setToken(token);
      final r1 = await repo.operatorStartProcessing('Q200');
      final r2 = await repo.operatorStartProcessing('Q200');
      expect(r1, true);
      expect(r2, false);
    });

    testWidgets('farmer cannot access operator UI', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // override currentUserProvider to be farmer
      // Directly build OperatorGuard with currentUser overridden to farmer
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserProvider.overrideWith((ref) => Future.value({'sub': 'f1', 'role': 'farmer', 'centre_ids': []}))
      ], child: const MaterialApp(home: OperatorGuard(centreId: 'C1'))));
      await tester.pumpAndSettle();
      expect(find.text('Forbidden: Operator access only'), findsOneWidget);
    });

    testWidgets('operator with assignment can access dashboard', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final user = {'sub': 'op1', 'role': 'operator', 'centre_ids': ['C1']};
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserProvider.overrideWith((ref) => Future.value(user)),
        operatorDashboardProvider.overrideWith((ref, id) => Future.value({'centreName':'C1','date':'now','totalBookings':1,'checkedIn':0,'waiting':0,'processing':0,'completed':0,'noShow':0,'availableCapacity':0,'activeCounters':1})),
        operatorQueueProvider.overrideWith((ref, id) => Future.value([])),
      ], child: const MaterialApp(home: OperatorGuard(centreId: 'C1'))));
      await tester.pumpAndSettle();
      expect(find.text('Operator Dashboard'), findsOneWidget);
    });

    test('cannot complete twice', () async {
      final payload = {'sub': 'op1', 'role': 'operator', 'centre_ids': ['C1'], 'exp': DateTime.now().toUtc().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000};
      final token = 'hdr.' + base64Url.encode(utf8.encode(json.encode(payload))) + '.sig';
      await AuthService.setToken(token);
      final c1 = await repo.operatorComplete('Q300');
      final c2 = await repo.operatorComplete('Q300');
      expect(c1, true);
      expect(c2, false);
    });
  });
}
