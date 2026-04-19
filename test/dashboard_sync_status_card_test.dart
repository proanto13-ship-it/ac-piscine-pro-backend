import 'package:ac_piscine_pro/main.dart';
import 'package:ac_piscine_pro/services/sync_queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard sync card stays readable on iPhone width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DashboardSyncStatusCard(
                snapshot: SyncQueueSnapshot.defaults(),
                color: const Color(0xFF667085),
                statusLabel: 'Aucune synchronisation en cours',
                nextRetryLabel: '',
                onOpenDetails: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Synchronisation'), findsOneWidget);
    expect(find.text('Aucune synchronisation en cours'), findsOneWidget);
    expect(find.text('Voir le détail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
