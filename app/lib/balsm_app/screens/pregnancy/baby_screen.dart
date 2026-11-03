import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';
import 'pregnancy_add_screen.dart';
import 'pregnancy_kit.dart';

/// Opens baby [id]'s screen; with [rename] its name sheet opens at once.
Future<void> openBaby(BuildContext context, HealthProfileId id, {bool rename = false}) =>
    pushFamilyScreen<void>(context, (_) => BabyScreen(id: id, rename: rename));

/// One baby of the pregnancy (mother-child.jsx `MCBabyScreen`): its scans,
/// measurements and documents, an optional name, and "Add a record".
class BabyScreen extends ConsumerStatefulWidget {
  const BabyScreen({super.key, required this.id, this.rename = false});
  final HealthProfileId id;
  final bool rename;
  @override
  ConsumerState<BabyScreen> createState() => _BabyScreenState();
}

class _BabyScreenState extends ConsumerState<BabyScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.rename) WidgetsBinding.instance.addPostFrameCallback((_) => _rename());
  }

  PregnancyBaby? _baby(Pregnancy? preg) {
    if (preg == null) return null;
    final babies = ref.read(pregnancyBabiesProvider(preg.id)).valueOrNull ?? const <PregnancyBaby>[];
    return babies.where((b) => b.id == widget.id && b.isActive).firstOrNull;
  }

  Future<void> _rename() async {
    final b = _baby(ref.read(activePregnancyProvider));
    if (b == null || !mounted) return;
    final s = AppScope.of(context);
    await showAppSheet<void>(context, textDirection: s.dir, builder: (_) => _RenameSheet(baby: b));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyProvider);
    final babies =
        preg == null ? const <PregnancyBaby>[] : ref.watch(pregnancyBabiesProvider(preg.id)).valueOrNull ?? const [];
    final b = babies.where((x) => x.id == widget.id && x.isActive).firstOrNull;
    if (preg == null || b == null) return const Scaffold(backgroundColor: Colors.white);
    final items = (ref.watch(pregnancyItemsProvider(preg.id)).valueOrNull ?? const <PregnancyItem>[])
        .where((i) => i.isAbout(b.id))
        .toList();
    final sections = [
      (ItemKind.scan, p.sec_scan),
      (ItemKind.measure, p.sec_measure),
      (ItemKind.doc, p.sec_doc),
    ];
    return FamilyScaffold(
      title: babyLabel(s, b, babies),
      trailing: RoundBtn(icon: LucideIcons.pencil, semanticLabel: p.rename, iconSize: 18, onTap: _rename),
      footer: PButton(p.add_record,
          icon: LucideIcons.paperclip,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: () => openPregnancyAdd(context, babyIds: [b.id])),
      children: [
        if (b.givenName == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(p.name_hint, style: Typo.bodySm(ar: s.rtl)),
          ),
        for (final (kind, title) in sections) ...[
          FamilySecHead(title),
          if (items.where((i) => i.kind == kind).isEmpty)
            Text(p.nothing_yet, style: Typo.meta(ar: s.rtl))
          else
            RowsCard(children: [
              for (final it in items.where((i) => i.kind == kind))
                PregnancyItemRow(item: it, pregnancy: preg, babies: babies),
            ]),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(p.as_entered, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        ),
      ],
    );
  }
}

class _RenameSheet extends ConsumerStatefulWidget {
  const _RenameSheet({required this.baby});
  final PregnancyBaby baby;
  @override
  ConsumerState<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<_RenameSheet> {
  late final _name = TextEditingController(text: widget.baby.givenName ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final r = await ref.read(pregnancyBabiesPortProvider).renameBaby(widget.baby.id, _name.text, now: DateTime.now());
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isSuccess) {
      Navigator.pop(context);
    } else {
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FamilySheet(title: s.strings.family.f_name, sub: p.name_sub, children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: BirthDetails.maxNameLength,
          decoration: fieldDecoration(s, p.name_ph).copyWith(counterText: ''),
        ),
        const SizedBox(height: 14),
        PButton(s.strings.family.save,
            large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _saving ? null : _save),
      ]),
    );
  }
}
