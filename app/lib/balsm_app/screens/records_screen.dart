import 'package:core/core.dart' show currentUserIdProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:records/records.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/badges.dart';
import 'records_detail.dart';

/// Live vault contents for the signed-in user, newest first. Empty when signed
/// out rather than throwing — the screen is reachable before a profile exists.
final recordListProvider = StreamProvider.autoDispose<List<RecordDocument>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(recordsDataSourceProvider).watchAll();
});

/// Per-type chrome — `RECORD_TYPES` in the design.
({IconData icon, Color fg, Color bg}) recordTypeStyle(RecordType type) => switch (type) {
      RecordType.lab => (icon: LucideIcons.flaskConical, fg: T.petalMint600, bg: T.petalMint50),
      RecordType.scan => (icon: LucideIcons.scanLine, fg: T.petalBlue, bg: T.petalBlue50),
      RecordType.report => (icon: LucideIcons.fileText, fg: T.petalViolet, bg: T.petalViolet50),
    };

String recordTypeLabel(PatientAppState s, RecordType type) => switch (type) {
      RecordType.lab => s.strings.records.rec_lab,
      RecordType.scan => s.strings.records.rec_scan,
      RecordType.report => s.strings.records.rec_report,
    };

String recordTypeLabelOne(PatientAppState s, RecordType type) => switch (type) {
      RecordType.lab => s.strings.records.rec_lab_one,
      RecordType.scan => s.strings.records.rec_scan_one,
      RecordType.report => s.strings.records.rec_report_one,
    };

/// Health-records vault — searchable list of on-device document metadata.
///
/// PHI, on-device only: the drift source is user-partitioned and the document
/// bytes never leave the app documents directory.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  /// null = "All"; otherwise the single type being shown.
  RecordType? _filter;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Title, result note, and tags are all searchable — the design matches on
  /// every visible field, not just the title.
  bool _matches(RecordDocument r, String q) {
    if (q.isEmpty) return true;
    final hay = [r.title, r.resultNote ?? '', ...r.tags].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final async = ref.watch(recordListProvider);
    final q = _query.text.trim().toLowerCase();
    final all = async.valueOrNull ?? const <RecordDocument>[];
    final shown = all.where((r) => (_filter == null || r.type == _filter) && _matches(r, q)).toList();
    final filtering = q.isNotEmpty || _filter != null;

    return Stack(children: [
      ContentColumn(
        maxWidth: 720,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PadTop(),
          AppBarRow(children: [
            if (widget.onBack != null) ...[
              RoundBtn(icon: backArrow(context), onTap: widget.onBack),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(s.strings.records.records, style: Typo.heading(ar: s.rtl))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SearchField(controller: _query, onChanged: () => setState(() {})),
          ),
          _FilterChips(selected: _filter, onSelect: (f) => setState(() => _filter = f)),
          Expanded(
            child: async.isLoading
                ? const _LoadingList()
                : shown.isEmpty
                    ? _EmptyState(
                        filtering: filtering,
                        query: _query.text,
                        onClear: () => setState(() {
                          _query.clear();
                          _filter = null;
                        }),
                        onAdd: () => _openAdd(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _RecordCard(
                          record: shown[i],
                          onTap: () => _openDetail(context, shown[i]),
                        ),
                      ),
          ),
        ]),
      ),
      // `.rec-fab` — only once the vault has something in it; the empty state
      // carries its own primary call to action.
      if (!async.isLoading && all.isNotEmpty)
        PositionedDirectional(
          end: 20,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: _RecordFab(onTap: () => _openAdd(context)),
        ),
    ]);
  }

  void _openDetail(BuildContext context, RecordDocument record) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordDetailScreen(record: record)));
  }

  void _openAdd(BuildContext context) => showAddRecord(context);
}

/// `.b-input` with a leading search glyph and a clear affordance.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
      decoration: InputDecoration(
        hintText: s.strings.records.rec_search_ph,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        prefixIcon: const Icon(LucideIcons.search, size: 17, color: T.fg4),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: controller.text.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: T.ink100, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.x, size: 15, color: T.fg2),
                  ),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        border: _border(T.border),
        enabledBorder: _border(T.border),
        focusedBorder: _border(s.accent.main),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rMd),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// All / Lab / Scan / Report — a horizontally scrolling chip rail.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});
  final RecordType? selected;
  final ValueChanged<RecordType?> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final entries = <(RecordType?, String)>[
      (null, s.strings.records.all_records),
      for (final t in RecordType.values) (t, recordTypeLabel(s, t)),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label) = entries[i];
          final on = selected == type;
          return GestureDetector(
            onTap: () => onSelect(type),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? s.accent.bg : Colors.white,
                borderRadius: BorderRadius.circular(T.rPill),
                border: Border.all(color: on ? s.accent.main : T.border, width: 1.5),
              ),
              child: Text(label,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: on ? s.accent.d : T.fg2)),
            ),
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});
  final RecordDocument record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final style = recordTypeStyle(record.type);
    final source = record.source.isSelf ? s.strings.records.rec_self : record.source.value;
    return PCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(T.rMd)),
          child: Icon(style.icon, size: 22, color: style.fg),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 2),
            Text('${formatRecordDate(record.takenAt, s)} · $source',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        const SizedBox(width: 8),
        StorageBadge(storage: s.storageProvider),
        const SizedBox(width: 6),
        Chevron(rtl: s.rtl),
      ]),
    );
  }
}

/// Skeleton rows while the vault loads — `DSSkeleton` in the design.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => PCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Shimmer(width: 46, height: 46, radius: T.rMd),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Shimmer(height: 13, width: 180.0 - i * 16),
                const SizedBox(height: 6),
                const Shimmer(height: 11, width: 110),
              ]),
            ),
          ]),
        ),
      );
}

/// Two distinct empty states: nothing in the vault at all, versus nothing
/// matching the current search/filter. They offer different actions.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filtering,
    required this.query,
    required this.onClear,
    required this.onAdd,
  });
  final bool filtering;
  final String query;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.strings.records;
    return SingleChildScrollView(
      child: PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
        child: Column(children: [
          Icon(filtering ? LucideIcons.searchX : LucideIcons.folderOpen, size: 36, color: T.fg4),
          const SizedBox(height: 14),
          Text(filtering ? r.rec_no_results : r.rec_empty,
              textAlign: TextAlign.center,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          const SizedBox(height: 8),
          Text(
            filtering ? (query.isNotEmpty ? '${r.rec_no_results_h} "$query"' : r.rec_no_results_h2) : r.rec_empty_h,
            textAlign: TextAlign.center,
            style: Typo.meta(ar: s.rtl),
          ),
          const SizedBox(height: 16),
          if (filtering)
            PButton(r.rec_clear_filters,
                icon: LucideIcons.rotateCcw,
                variant: BtnVariant.soft,
                size: BtnSize.sm,
                accent: s.accent,
                ar: s.rtl,
                onTap: onClear)
          else
            PButton(s.strings.settings.add_record, icon: LucideIcons.plus, accent: s.accent, ar: s.rtl, onTap: onAdd),
        ]),
      ),
    );
  }
}

/// `.rec-fab` — 56pt floating add button over the list.
class _RecordFab extends StatelessWidget {
  const _RecordFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: s.accent.main, shape: BoxShape.circle, boxShadow: s.accent.boxShadow),
        child: const Icon(LucideIcons.plus, size: 24, color: Colors.white),
      ),
    );
  }
}

/// Localized record date. Falls back to the ISO day so the list never shows a
/// blank where a date belongs.
String formatRecordDate(DateTime d, PatientAppState s) {
  final months = s.rtl
      ? const [
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'سبتمبر',
          'أكتوبر',
          'نوفمبر',
          'ديسمبر'
        ]
      : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = d.day.toString().padLeft(2, '0');
  return '$day ${months[d.month - 1]} ${d.year}';
}
