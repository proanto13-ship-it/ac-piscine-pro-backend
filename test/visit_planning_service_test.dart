import 'package:ac_piscine_pro/models/client.dart';
import 'package:ac_piscine_pro/models/visit_plan.dart';
import 'package:ac_piscine_pro/models/water_analysis.dart';
import 'package:ac_piscine_pro/services/visit_planning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Client buildClient({
    required String id,
    required String name,
    String analysisDateIso = '2026-04-10T10:00:00Z',
    int visitFrequencyDays = 14,
    bool withAnalysis = true,
  }) {
    return Client(
      id: id,
      name: name,
      phone: '',
      email: '',
      address: '',
      volume: 30,
      treatment: 'chlore',
      bassinType: '',
      revetement: '',
      filtration: '',
      equipements: '',
      visitFrequencyDays: visitFrequencyDays,
      createdAtIso: '2026-04-01T10:00:00Z',
      notes: '',
      analyses: withAnalysis
          ? [
              WaterAnalysis(
                dateIso: analysisDateIso,
                ph: 7.2,
                chlore: 2,
                tac: 100,
                th: 200,
                stabilisant: 30,
                temperature: 24,
                tds: 0,
                lsi: 0,
                stabilityScore: 90,
                eauSalee: false,
                liner: true,
                observation: '',
                mainOeuvre: 0,
              ),
            ]
          : [],
      interventions: [],
      financialDocuments: [],
    );
  }

  test('dashboard falls back to legacy client rhythm when no explicit plan',
      () {
    final client = buildClient(id: 'c1', name: 'Client 1');
    final dashboard = VisitPlanningService.buildDashboard(
      clients: [client],
      plans: const [],
      now: DateTime(2026, 4, 20),
    );

    expect(dashboard.today, isEmpty);
    expect(dashboard.overdue, isEmpty);
    expect(dashboard.thisWeek, hasLength(1));
  });

  test('explicit plan overrides legacy next visit date and note', () {
    final client = buildClient(id: 'c1', name: 'Client 1');
    final plan = VisitPlan(
      id: 'p1',
      clientId: 'c1',
      frequencyDays: 21,
      nextVisitAtIso: '2026-04-25T08:00:00Z',
      note: 'Controle filtre',
      reminderEnabled: true,
      createdAtIso: '2026-04-17T08:00:00Z',
    );

    final entry = VisitPlanningService.entryForClient(
      client: client,
      plans: [plan],
    );

    expect(entry.nextVisitDate, isNotNull);
    expect(entry.nextVisitDate!.day, 25);
    expect(entry.frequencyDays, 21);
    expect(entry.note, 'Controle filtre');
    expect(entry.reminderEnabled, isTrue);
  });

  test('advancePlanForClient moves next visit after completion date', () {
    final plan = VisitPlan(
      id: 'p1',
      clientId: 'c1',
      frequencyDays: 14,
      nextVisitAtIso: '2026-04-20T08:00:00Z',
      note: '',
      reminderEnabled: false,
      createdAtIso: '2026-04-17T08:00:00Z',
    );

    final advanced = VisitPlanningService.advancePlanForClient(
      existing: [plan],
      clientId: 'c1',
      completedAt: DateTime(2026, 4, 21, 9),
    );

    expect(advanced, hasLength(1));
    expect(advanced.single.nextVisitAtIso.startsWith('2026-05-05'), isTrue);
  });
}
