import 'dart:io';

import 'package:flutter/material.dart';

import '../mvc_models/assignment.dart';
import '../mvc_models/execution.dart';
import '../mvc_services/photo_crypto_service.dart';

class TaskExecutionDetailScreen extends StatelessWidget {
  const TaskExecutionDetailScreen({super.key});

  Future<Widget> _buildPhotoWidget(String imagePath) async {
    if (imagePath.endsWith('.enc')) {
      final bytes = await PhotoCryptoService().decryptFileToBytes(imagePath);
      return Image.memory(bytes, fit: BoxFit.contain);
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('File foto tidak ditemukan di perangkat');
    }
    return Image.file(file, fit: BoxFit.contain);
  }

  Future<void> _openPhotoDialog(BuildContext context, String imagePath) async {
    if (imagePath.trim().isEmpty || imagePath.trim() == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak tersedia.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Foto Hasil Task'),
        content: SizedBox(
          width: 360,
          height: 480,
          child: FutureBuilder<Widget>(
            future: _buildPhotoWidget(imagePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Gagal memuat foto: ${snapshot.error}'),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: snapshot.data ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year;
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final assignment = args['assignment'] as Assignment;
    final execution = args['execution'] as TaskExecution;

    final hasPhoto = (execution.imagePath ?? '').trim().isNotEmpty &&
        (execution.imagePath ?? '').trim() != '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Detail Task Selesai'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3C8D7A), Color(0xFF54A792)],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1EBE7)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C8D7A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    execution.taskState,
                    style: const TextStyle(
                      color: Color(0xFF2D7D6B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtDate(execution.taskDate),
                  style: const TextStyle(
                    color: Color(0xFF6A8D84),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1EBE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPK ${assignment.spkNumber} • ${assignment.taskName}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF225A4D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lokasi: Estate ${assignment.estate} • Divisi ${assignment.division} • '
                  'Blok ${assignment.block} • Baris ${assignment.rowNumber} • Pohon ${assignment.treeNumber}',
                ),
                const SizedBox(height: 6),
                Text('Petugas: ${execution.petugas}'),
                const SizedBox(height: 10),
                const Text(
                  'Catatan',
                  style: TextStyle(
                    color: Color(0xFF225A4D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(execution.keterangan.trim().isEmpty ? '-' : execution.keterangan),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
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
                    const Icon(Icons.photo_library_rounded, color: Color(0xFF2D8A73)),
                    const SizedBox(width: 8),
                    const Text(
                      'Foto Hasil',
                      style: TextStyle(
                        color: Color(0xFF225A4D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasPhoto ? 'Tersedia' : 'Tidak ada',
                      style: TextStyle(
                        color: hasPhoto ? Colors.green.shade700 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: hasPhoto
                        ? () => _openPhotoDialog(context, (execution.imagePath ?? '').trim())
                        : null,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Buka Foto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

