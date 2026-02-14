// screens/assignment_detail_screen.dart

import 'package:flutter/material.dart';
import '../../mvc_models/assignment.dart';
import '../../mvc_models/sop_master.dart';
import '../../mvc_models/sop_step.dart';
import '../../mvc_models/task_sop_check.dart';
import '../mvc_dao/dao_sop.dart';

class AssignmentContent extends StatefulWidget {
  const AssignmentContent({super.key});
  @override
  State<AssignmentContent> createState() => _AssignmentContentState();
}

class _AssignmentContentState extends State<AssignmentContent> {
  final SopDao _sopDao = SopDao();
  final Map<String, bool> _checkedState = {};
  final Map<String, TextEditingController> _noteControllers = {};

  SopMaster? _sop;
  List<SopStep> _steps = [];
  bool _loadingSop = true;

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSop(Assignment assignment) async {
    setState(() => _loadingSop = true);
    try {
      final sop = await _sopDao.resolveSopForAssignment(assignment);
      if (sop == null) {
        if (mounted) {
          setState(() {
            _sop = null;
            _steps = [];
            _loadingSop = false;
          });
        }
        return;
      }

      final steps = await _sopDao.getStepsBySopId(sop.sopId);
      final checkedMap = await _sopDao.getCheckedStateMap(assignment.id, sop.sopId);

      if (!mounted) return;
      setState(() {
        _sop = sop;
        _steps = steps;
        _checkedState
          ..clear()
          ..addAll(checkedMap);
        _loadingSop = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSop = false;
      });
    }
  }

  bool _requiredComplete() {
    for (final s in _steps) {
      if (s.isRequired == 1 && (_checkedState[s.stepId] != true)) {
        return false;
      }
    }
    return true;
  }

  TextEditingController _noteControllerFor(String stepId) {
    return _noteControllers.putIfAbsent(stepId, () => TextEditingController());
  }

  Future<void> _saveCheck(Assignment assignment, SopStep step, bool checked) async {
    final sop = _sop;
    if (sop == null) return;

    final note = _noteControllerFor(step.stepId).text.trim();
    final check = TaskSopCheck(
      checkId: '${assignment.id}-${step.stepId}',
      executionId: 'PRE-${assignment.id}',
      assignmentId: assignment.id,
      spkNumber: assignment.spkNumber,
      sopId: sop.sopId,
      stepId: step.stepId,
      isChecked: checked ? 1 : 0,
      note: note,
      evidencePath: null,
      checkedAt: DateTime.now().toIso8601String(),
      flag: 0,
    );
    await _sopDao.upsertCheck(check);
  }

  void _onCompletePressed(BuildContext context, Assignment assignment) {
    if (!_requiredComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Checklist SOP wajib belum lengkap. Lengkapi dulu sebelum menyelesaikan task.',
          ),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/isiTugas',
      arguments: {'assignment': assignment, 'taskState': 'SELESAI'},
    );
  }
  @override
  Widget build(BuildContext context) {
    final assignment = ModalRoute.of(context)!.settings.arguments as Assignment;

    if (_loadingSop && _steps.isEmpty && _sop == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSop(assignment);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Detail Task'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F6A5A), Color(0xFF2D8A73)],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(assignment),
            const SizedBox(height: 12),
            _sopSection(assignment),
            const SizedBox(height: 12),
            _metaSection(assignment),
            const SizedBox(height: 12),
            _detailSection(assignment),
            const SizedBox(height: 12),
            _actionSection(context, assignment),
          ],
        ),
      ),
    );
  }

  Widget _sopSection(Assignment assignment) {
    if (_loadingSop) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1EBE7)),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Memuat checklist SOP...'),
          ],
        ),
      );
    }

    if (_sop == null || _steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1EBE7)),
        ),
        child: const Text(
          'Checklist SOP belum tersedia untuk task ini.',
          style: TextStyle(color: Color(0xFF5E8479)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, color: Color(0xFF1F6A5A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sop!.sopName,
                  style: const TextStyle(
                    color: Color(0xFF225A4D),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6A5A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _requiredComplete() ? 'Wajib: OK' : 'Wajib: Belum',
                  style: TextStyle(
                    color: _requiredComplete()
                        ? const Color(0xFF1F6A5A)
                        : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._steps.map((step) {
            final checked = _checkedState[step.stepId] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FCFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3EEEA)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: checked,
                        activeColor: const Color(0xFF2D8A73),
                        onChanged: (v) async {
                          final next = v == true;
                          setState(() {
                            _checkedState[step.stepId] = next;
                          });
                          await _saveCheck(assignment, step, next);
                        },
                      ),
                      Expanded(
                        child: Text(
                          '${step.stepOrder}. ${step.stepTitle}',
                          style: const TextStyle(
                            color: Color(0xFF225A4D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (step.isRequired == 1)
                        const Icon(Icons.priority_high_rounded,
                            color: Colors.redAccent, size: 16),
                    ],
                  ),
                  if (step.evidenceType == 'note' && checked)
                    TextField(
                      controller: _noteControllerFor(step.stepId),
                      decoration: const InputDecoration(
                        hintText: 'Catatan step (opsional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _saveCheck(assignment, step, checked);
                      },
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _heroCard(Assignment assignment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6A5A), Color(0xFF2D8A73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6A5A).withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    assignment.spkNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  assignment.taskName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mandor: ${assignment.petugas}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaSection(Assignment assignment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBE7)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _metaChip(Icons.forest_rounded, 'Estate ${assignment.estate}'),
          _metaChip(Icons.groups_rounded, 'Divisi ${assignment.division}'),
          _metaChip(Icons.grid_view_rounded, 'Blok ${assignment.block}'),
          _metaChip(
            Icons.format_list_numbered_rounded,
            'Baris ${assignment.rowNumber} • Pohon ${assignment.treeNumber}',
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1F6A5A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1F6A5A).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1F6A5A)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF225A4D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(Assignment assignment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Penugasan',
            style: TextStyle(
              color: Color(0xFF225A4D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.confirmation_number_rounded, 'Nomor SPK', assignment.spkNumber),
          _infoRow(Icons.work_outline_rounded, 'Nama Tugas', assignment.taskName),
          _infoRow(Icons.person_outline_rounded, 'Petugas', assignment.petugas),
          _infoRow(
            Icons.location_on_outlined,
            'Lokasi',
            '${assignment.division}/${assignment.block}',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2D8A73)),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5E8479),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF225A4D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionSection(BuildContext context, Assignment assignment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aksi Task',
            style: TextStyle(
              color: Color(0xFF225A4D),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih aksi untuk melanjutkan pekerjaan lapangan.',
            style: TextStyle(color: Color(0xFF5E8479), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _onCompletePressed(context, assignment),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text(
                'SELESAIKAN TASK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF225A4D),
                side: BorderSide(color: const Color(0xFF225A4D).withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pushNamed(
                context,
                '/isiTugas',
                arguments: {'assignment': assignment, 'taskState': 'TERTUNDA'},
              ),
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text(
                'TUNDA TASK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
