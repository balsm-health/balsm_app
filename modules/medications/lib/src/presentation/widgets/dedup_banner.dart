import 'package:flutter/material.dart';

// Shown on meds.today when restore-time dedup detected. Per Q4 FR-009e.
class DedupBanner extends StatefulWidget {
  const DedupBanner({super.key});

  @override
  State<DedupBanner> createState() => _DedupBannerState();
}

class _DedupBannerState extends State<DedupBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5B428)),
      ),
      child: Row(
        children: [
          const Icon(Icons.merge_type, color: Color(0xFFE5B428), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Some dose entries appeared twice and were merged. Review your today list.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _dismissed = true),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
