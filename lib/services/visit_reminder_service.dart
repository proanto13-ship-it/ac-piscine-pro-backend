import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'local_storage_service.dart';
import 'visit_planning_service.dart';

class VisitReminderService {
  static String get fileName =>
      AppEnvironment.storageName('visit_reminder_state.json');

  static Future<void> maybeShowReminder(
    BuildContext context, {
    required VisitPlanningDashboard dashboard,
  }) async {
    final reminderCount = dashboard.reminderDueCount;
    if (reminderCount <= 0 || !context.mounted) {
      return;
    }

    final state = await LocalStorageService.readJsonMap(fileName);
    final now = DateTime.now().toLocal();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (state?['lastShownDay']?.toString() == todayKey) {
      return;
    }

    await LocalStorageService.writeJson(
      fileName,
      {
        'lastShownDay': todayKey,
        'count': reminderCount,
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reminderCount == 1
              ? '1 visite planifiée nécessite un rappel aujourd’hui.'
              : '$reminderCount visites planifiées nécessitent un rappel aujourd’hui.',
        ),
      ),
    );
  }
}
