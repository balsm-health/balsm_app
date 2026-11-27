import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

// Shown on meds.today when restore-time dedup detected. Per Q4 FR-009e.
class DedupBanner extends ConsumerStatefulWidget {
  const DedupBanner({super.key});

  @override
  ConsumerState<DedupBanner> createState() => _DedupBannerState();
}

class _DedupBannerState extends ConsumerState<DedupBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(medicationsStringsProvider);
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.merge_type, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              m.dedupBody,
              style: const TextStyle(fontSize: FontSizes.bodySm, height: 1.4),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _dismissed = true),
            tooltip: coreMessagesOf(context).common.dismiss,
          ),
        ],
      ),
    );
  }
}
