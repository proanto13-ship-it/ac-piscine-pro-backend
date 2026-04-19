import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/visit_plan.dart';

class VisitPlanPage extends StatefulWidget {
  final Client client;
  final VisitPlan? existingPlan;

  const VisitPlanPage({
    super.key,
    required this.client,
    this.existingPlan,
  });

  @override
  State<VisitPlanPage> createState() => _VisitPlanPageState();
}

class _VisitPlanPageState extends State<VisitPlanPage> {
  late final TextEditingController _frequencyController;
  late final TextEditingController _noteController;
  late DateTime _nextVisitDate;
  late bool _reminderEnabled;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    final initialDate = plan == null
        ? widget.client.nextVisitDate ??
            DateTime.now().add(const Duration(days: 14))
        : DateTime.tryParse(plan.nextVisitAtIso)?.toLocal() ??
            DateTime.now().add(const Duration(days: 14));
    _nextVisitDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _frequencyController = TextEditingController(
      text:
          (plan?.frequencyDays ?? widget.client.visitFrequencyDays).toString(),
    );
    _noteController = TextEditingController(text: plan?.note ?? '');
    _reminderEnabled = plan?.reminderEnabled ?? false;
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickNextDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextVisitDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _nextVisitDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _save() {
    final frequencyDays =
        int.tryParse(_frequencyController.text.trim())?.clamp(7, 90) ?? 14;
    final nowIso = DateTime.now().toIso8601String();
    final plan = VisitPlan(
      id: widget.existingPlan?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      clientId: widget.client.id,
      frequencyDays: frequencyDays,
      nextVisitAtIso: _nextVisitDate.toIso8601String(),
      note: _noteController.text.trim(),
      reminderEnabled: _reminderEnabled,
      createdAtIso: widget.existingPlan?.createdAtIso ?? nowIso,
      updatedAtIso: nowIso,
    );
    Navigator.of(context).pop<VisitPlan>(plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Planifier ${widget.client.name}'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _frequencyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fréquence (jours)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickNextDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Prochaine visite : ${_nextVisitDate.day.toString().padLeft(2, '0')}/${_nextVisitDate.month.toString().padLeft(2, '0')}/${_nextVisitDate.year}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _reminderEnabled,
            onChanged: (value) => setState(() => _reminderEnabled = value),
            title: const Text('Rappel local dans l’app'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer le passage récurrent'),
          ),
          if (widget.existingPlan != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop<String>('delete'),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer cette planification'),
            ),
          ],
        ],
      ),
    );
  }
}
