// lib/screens/sync/sync_widgets.dart

import 'package:flutter/material.dart';
import 'sync_models.dart';

/// Widget untuk menampilkan progress fetching data
class FetchProgressSection extends StatelessWidget {
  final bool isFetching;
  final double fetchProgress;
  final String fetchLabel;
  final Color primary;
  final Color progressBg;
  final Color textColor;

  const FetchProgressSection({
    super.key,
    required this.isFetching,
    required this.fetchProgress,
    required this.fetchLabel,
    required this.primary,
    required this.progressBg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E7E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, size: 18, color: Color(0xFF2D8A73)),
              const SizedBox(width: 8),
              Text(
                "Pengumpulan Data",
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                "${(fetchProgress * 100).toInt()}%",
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: fetchProgress,
              backgroundColor: progressBg,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(fetchLabel, style: TextStyle(color: textColor.withValues(alpha: 0.9))),
          if (!isFetching)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text("Data siap diproses", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan card batch data
class BatchDataCard extends StatelessWidget {
  final Map<BatchKind, BatchState> states;
  final int tugasCount;
  final int kesehatanCount;
  final int reposisiCount;
  final int observasiCount;
  final int auditlogCount;
  final int sprlogCount;
  final Color secondary;
  final Color textColor;

  const BatchDataCard({
    super.key,
    required this.states,
    required this.tugasCount,
    required this.kesehatanCount,
    required this.reposisiCount,
    required this.observasiCount,
    required this.auditlogCount,
    required this.sprlogCount,
    required this.secondary,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E7E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xFF2D8A73), size: 18),
              const SizedBox(width: 8),
              Text(
                "Batch Data Siap Dikirim",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BatchRow(
            kind: BatchKind.tugas,
            count: tugasCount,
            state: states[BatchKind.tugas] ?? BatchState.idle,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          BatchRow(
            kind: BatchKind.kesehatan,
            count: kesehatanCount,
            state: states[BatchKind.kesehatan] ?? BatchState.idle,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          BatchRow(
            kind: BatchKind.reposisi,
            count: reposisiCount,
            state: states[BatchKind.reposisi] ?? BatchState.idle,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          BatchRow(
            kind: BatchKind.observasi,
            count: observasiCount,
            state: states[BatchKind.observasi] ?? BatchState.idle,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          BatchRow(
            kind: BatchKind.sprlog,
            count: sprlogCount,
            state: states[BatchKind.sprlog] ?? BatchState.idle,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          BatchRow(
            kind: BatchKind.auditlog,
            count: auditlogCount,
            state: states[BatchKind.auditlog] ?? BatchState.idle,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan satu baris batch
class BatchRow extends StatelessWidget {
  final BatchKind kind;
  final int count;
  final BatchState state;
  final Color textColor;

  const BatchRow({
    super.key,
    required this.kind,
    required this.count,
    required this.state,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Widget trailing = Text(
      "$count item",
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
    );

    switch (state) {
      case BatchState.fetching:
        dotColor = Colors.orange;
        break;
      case BatchState.sending:
        dotColor = Colors.amber;
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        );
        break;
      case BatchState.success:
        dotColor = Colors.green.shade400;
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 6),
            trailing,
          ],
        );
        break;
      case BatchState.failed:
        dotColor = Colors.redAccent;
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 6),
            trailing,
          ],
        );
        break;
      default:
        dotColor = Colors.green.shade700;
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(kind.label, style: TextStyle(color: textColor)),
        ),
        trailing,
      ],
    );
  }
}

/// Widget untuk overlay saat mengirim data
class SendingOverlay extends StatelessWidget {
  final double sendProgress;
  final String sendLabel;
  final Color primary;
  final Color progressBg;

  const SendingOverlay({
    super.key,
    required this.sendProgress,
    required this.sendLabel,
    required this.primary,
    required this.progressBg,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 36, color: Colors.orange),
              const SizedBox(height: 10),
              const Text(
                "Mengirim data ke server...",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                "Halaman dikunci sampai proses selesai.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 10,
                value: sendProgress,
                backgroundColor: progressBg,
                valueColor: AlwaysStoppedAnimation(primary),
              ),
              const SizedBox(height: 10),
              Text(sendLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget untuk menampilkan hasil per batch
class BatchResultPanel extends StatelessWidget {
  final BatchKind kind;
  final String message;
  final BatchState state;
  final Color successColor;

  const BatchResultPanel({
    super.key,
    required this.kind,
    required this.message,
    required this.state,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty &&
        state != BatchState.failed &&
        state != BatchState.success) {
      return const SizedBox.shrink();
    }

    Color bg;
    if (state == BatchState.success) {
      bg = successColor.withValues(alpha: 0.14);
    } else if (state == BatchState.failed) {
      bg = Colors.redAccent.withValues(alpha: 0.12);
    } else {
      bg = Colors.white.withValues(alpha: 0.02);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                kind.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              if (state == BatchState.success)
                const Icon(Icons.check, color: Colors.green),
              if (state == BatchState.failed)
                const Icon(Icons.error, color: Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.isEmpty ? "Tidak ada detail respons." : message,
            style: const TextStyle(fontFamily: "monospace", fontSize: 13),
          ),
        ],
      ),
    );
  }
}
