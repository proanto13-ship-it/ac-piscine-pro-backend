import '../models/client.dart';
import '../models/visit_plan.dart';

class VisitPlanningEntry {
  final Client client;
  final VisitPlan? plan;
  final DateTime? nextVisitDate;
  final String note;
  final int frequencyDays;

  const VisitPlanningEntry({
    required this.client,
    required this.plan,
    required this.nextVisitDate,
    required this.note,
    required this.frequencyDays,
  });

  bool get hasPlan => plan != null;
  bool get reminderEnabled => plan?.reminderEnabled == true;
}

class VisitPlanningDashboard {
  final List<VisitPlanningEntry> today;
  final List<VisitPlanningEntry> thisWeek;
  final List<VisitPlanningEntry> overdue;
  final List<VisitPlanningEntry> firstVisits;

  const VisitPlanningDashboard({
    required this.today,
    required this.thisWeek,
    required this.overdue,
    required this.firstVisits,
  });

  int get reminderDueCount => [
        ...overdue.where((entry) => entry.reminderEnabled),
        ...today.where((entry) => entry.reminderEnabled),
      ].length;
}

class VisitPlanningService {
  static VisitPlan? planForClient({
    required String clientId,
    required List<VisitPlan> plans,
  }) {
    for (final plan in plans) {
      if (plan.clientId == clientId) {
        return plan;
      }
    }
    return null;
  }

  static DateTime? nextVisitDateForClient({
    required Client client,
    required List<VisitPlan> plans,
  }) {
    final plan = planForClient(clientId: client.id, plans: plans);
    if (plan != null && plan.nextVisitAtIso.trim().isNotEmpty) {
      return DateTime.tryParse(plan.nextVisitAtIso)?.toLocal();
    }
    return client.nextVisitDate;
  }

  static VisitPlanningEntry entryForClient({
    required Client client,
    required List<VisitPlan> plans,
  }) {
    final plan = planForClient(clientId: client.id, plans: plans);
    return VisitPlanningEntry(
      client: client,
      plan: plan,
      nextVisitDate: nextVisitDateForClient(client: client, plans: plans),
      note: plan?.note ?? '',
      frequencyDays: plan?.frequencyDays ?? client.visitFrequencyDays,
    );
  }

  static VisitPlanningDashboard buildDashboard({
    required List<Client> clients,
    required List<VisitPlan> plans,
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final weekEnd = today.add(const Duration(days: 7));

    final entries = clients
        .where((client) => !client.isDeleted)
        .map((client) => entryForClient(client: client, plans: plans))
        .toList();

    List<VisitPlanningEntry> sorted(Iterable<VisitPlanningEntry> source) {
      final items = source.toList();
      items.sort((a, b) {
        final nextA = a.nextVisitDate ?? DateTime(2100);
        final nextB = b.nextVisitDate ?? DateTime(2100);
        return nextA.compareTo(nextB);
      });
      return items;
    }

    bool isSameDay(DateTime value, DateTime other) {
      return value.year == other.year &&
          value.month == other.month &&
          value.day == other.day;
    }

    final overdue = sorted(entries.where((entry) {
      final next = entry.nextVisitDate;
      return next != null && next.isBefore(today);
    }));
    final dueToday = sorted(entries.where((entry) {
      final next = entry.nextVisitDate;
      return next != null && isSameDay(next, today);
    }));
    final thisWeek = sorted(entries.where((entry) {
      final next = entry.nextVisitDate;
      return next != null &&
          !next.isBefore(today) &&
          !next.isAfter(weekEnd) &&
          !isSameDay(next, today);
    }));
    final firstVisits =
        sorted(entries.where((entry) => entry.client.requiresFirstVisit));

    return VisitPlanningDashboard(
      today: dueToday,
      thisWeek: thisWeek,
      overdue: overdue,
      firstVisits: firstVisits,
    );
  }

  static List<VisitPlan> upsertPlan({
    required List<VisitPlan> existing,
    required VisitPlan plan,
  }) {
    final next = existing
        .where((item) => item.clientId != plan.clientId)
        .toList()
      ..add(plan);
    return next;
  }

  static List<VisitPlan> removePlanForClient({
    required List<VisitPlan> existing,
    required String clientId,
  }) {
    return existing.where((item) => item.clientId != clientId).toList();
  }

  static List<VisitPlan> advancePlanForClient({
    required List<VisitPlan> existing,
    required String clientId,
    DateTime? completedAt,
  }) {
    final completionDate = (completedAt ?? DateTime.now()).toLocal();
    return existing.map((plan) {
      if (plan.clientId != clientId) {
        return plan;
      }
      return plan.copyWith(
        nextVisitAtIso: completionDate
            .add(Duration(days: plan.frequencyDays))
            .toIso8601String(),
        updatedAtIso: completionDate.toIso8601String(),
      );
    }).toList();
  }
}
