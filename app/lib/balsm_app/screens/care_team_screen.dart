import 'dart:async';

import 'package:flutter/services.dart';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/vault_file_viewer.dart';
import '../widgets/photo_attach.dart';
import '../routes.dart';
import '../tokens.dart';
import 'profile_subscreens.dart';

/// Care team (`home.jsx` `CareTeamScreen` + its "Add a provider" sheet).
///
/// The design seeds a roster of sample doctors; this screen shows only what
/// the patient entered. Who treats a patient is sensitive, so the rows are
/// on-device PHI like the rest of the profile — nothing is fabricated and
/// nothing leaves the device.
///
void openCareTeam(BuildContext context) => pushSubScreen(context, (s) => const CareTeamScreen());

/// One provider's attached files (vault-relative paths), oldest first.
final careProviderFilesProvider = StreamProvider.autoDispose.family<List<String>, CareProviderId>((ref, id) {
  return ref.watch(profileDataSourceProvider).watchProviderFiles(id);
});

/// The patient's care team, newest write reflected immediately.
///
/// Scoped to the active health profile, so it empties on sign-out and
/// re-resolves for a dependant profile when P00X re-points
/// [currentProfileIdProvider].
final careTeamProvider = StreamProvider.autoDispose<List<CareProvider>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const <CareProvider>[]);
  return ref.watch(profileDataSourceProvider).watchProviders(profileId);
});

/// Icon per provider type — the design's `PROVIDER_TYPES` icons.
IconData careTypeIcon(CareProviderType type) => switch (type) {
      CareProviderType.doctor => LucideIcons.stethoscope,
      CareProviderType.nurse => LucideIcons.heartPulse,
      CareProviderType.carer => LucideIcons.handHeart,
      CareProviderType.pharmacy => LucideIcons.pill,
      CareProviderType.lab => LucideIcons.flaskConical,
      CareProviderType.physio => LucideIcons.activity,
      CareProviderType.clinic => LucideIcons.building2,
      CareProviderType.other => LucideIcons.userRound,
    };

/// Localized label per provider type.
String careTypeLabel(CareStrings c, CareProviderType type) => switch (type) {
      CareProviderType.doctor => c.care_t_doctor,
      CareProviderType.nurse => c.care_t_nurse,
      CareProviderType.carer => c.care_t_carer,
      CareProviderType.pharmacy => c.care_t_pharmacy,
      CareProviderType.lab => c.care_t_lab,
      CareProviderType.physio => c.care_t_physio,
      CareProviderType.clinic => c.care_t_clinic,
      CareProviderType.other => c.care_t_other,
    };

class CareTeamScreen extends ConsumerStatefulWidget {
  const CareTeamScreen({super.key});

  @override
  ConsumerState<CareTeamScreen> createState() => _CareTeamScreenState();
}

class _CareTeamScreenState extends ConsumerState<CareTeamScreen> {
  final _query = TextEditingController();

  /// null = the design's "All" chip.
  CareProviderType? _typeFilter;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Search across every field the card shows, plus the type label in both
  /// languages — the design searches the type name too, so "pharmacy" finds a
  /// pharmacy the patient named after its street.
  bool _matches(CareProvider p, String q, CareStrings c) {
    if (q.isEmpty) return true;
    final hay = [
      p.name,
      p.specialty ?? '',
      p.clinic ?? '',
      p.address ?? '',
      p.phone ?? '',
      p.phone2 ?? '',
      p.email ?? '',
      p.notes ?? '',
      careTypeLabel(c, p.type),
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  Future<void> _add() async {
    final added = await showAppSheet<bool>(
      context,
      size: SheetSize.lg,
      builder: (_) => const AddCareProviderSheet(),
    );
    if (added ?? false) {
      ref.invalidate(careTeamProvider);
      if (mounted) _snack(AppScope.of(context).strings.care.care_saved);
    }
  }

  /// The same sheet in edit mode. It returns `true` when the row was saved and
  /// `false` when it was deleted, so the toast can say which happened.
  Future<void> _edit(CareProvider p) async {
    final saved = await showAppSheet<bool>(
      context,
      size: SheetSize.lg,
      builder: (_) => AddCareProviderSheet(provider: p),
    );
    if (saved == null) return;
    ref.invalidate(careTeamProvider);
    if (!mounted) return;
    final c = AppScope.of(context).strings.care;
    _snack(saved ? c.care_saved : c.care_removed);
  }

  /// Opens a patient-pasted map link. Only `http(s)` reaches here — the entity
  /// gates that — and nothing about the destination is logged.
  Future<void> _directions(CareProvider p) async {
    final uri = Uri.parse(p.mapUrl!.trim());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack(AppScope.of(context).strings.care.care_save_failed);
    }
  }

  /// `tel:` the number the patient saved. Nothing is logged: the number is
  /// PHI-adjacent and only ever reaches the dialler.
  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri)) {
      if (mounted) _snack(AppScope.of(context).strings.care.care_save_failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.care;
    final team = ref.watch(careTeamProvider).valueOrNull ?? const <CareProvider>[];
    final q = _query.text.trim().toLowerCase();
    final shown = team.where((p) => (_typeFilter == null || p.type == _typeFilter) && _matches(p, q, c)).toList();

    // Only offer chips for types the patient actually has (design: only
    // `presentTypes`, and never a lone chip beside "All").
    final present = CareProviderType.values.where((t) => team.any((p) => p.type == t)).toList();

    return SubScreen(
      s: s,
      title: s.strings.profile.p_care,
      // `home.jsx` replaced the dashed "Add a care provider" row with a FAB,
      // so adding is reachable without scrolling past the whole roster.
      floating: _CareFab(onTap: _add),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
          child: Text(c.care_intro, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
        ),
        if (team.isNotEmpty) ...[
          _CareSearchField(controller: _query, hint: c.care_search_ph, onChanged: () => setState(() {})),
          if (present.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _TypeChip(
                icon: LucideIcons.users,
                label: c.care_all,
                active: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              for (final t in present)
                _TypeChip(
                  icon: careTypeIcon(t),
                  label: careTypeLabel(c, t),
                  active: _typeFilter == t,
                  onTap: () => setState(() => _typeFilter = t),
                ),
            ]),
          ],
          const SizedBox(height: 16),
        ],
        for (final p in shown) ...[
          _ProviderCard(
            provider: p,
            onCall: _call,
            onEdit: () => _edit(p),
            onDirections: p.hasDirections ? () => _directions(p) : null,
          ),
          const SizedBox(height: 12),
        ],
        // Two different nothings: an empty care team asks to be filled, a
        // filtered-out one says the search found nothing.
        if (team.isEmpty)
          PCard(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(children: [
              const Icon(LucideIcons.stethoscope, size: 36, color: T.ink300),
              const SizedBox(height: 12),
              Text(c.care_empty,
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
              const SizedBox(height: 4),
              Text(c.care_add_help,
                  textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
            ]),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 4),
            child: Column(children: [
              const Icon(LucideIcons.searchX, size: 26, color: T.ink300),
              const SizedBox(height: 10),
              Text(c.care_no_match, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(c.care_no_match_h, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        PButton(
          c.care_find,
          icon: LucideIcons.search,
          variant: BtnVariant.ghost,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: () {
            Navigator.pop(context);
            s.setTab(AppTab.map);
          },
        ),
        // `<div style={{ height: 72 }} />` — room for the FAB so it never
        // sits on top of the last card.
        const SizedBox(height: 72),
      ],
    );
  }
}

/// `.rec-fab` with the add-provider glyph. Same 56pt disc as the records
/// vault's, so the two "add" actions read as one affordance.
class _CareFab extends StatelessWidget {
  const _CareFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      label: s.strings.care.care_add,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.93,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.accent.main, shape: BoxShape.circle, boxShadow: s.accent.boxShadow),
          child: const Icon(LucideIcons.userPlus, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// One care-team member. Mirrors the design card: type disc, name with its
/// type badge, then only the lines the patient actually filled in.
class _ProviderCard extends ConsumerStatefulWidget {
  const _ProviderCard({
    required this.provider,
    required this.onCall,
    required this.onEdit,
    this.onDirections,
  });
  final CareProvider provider;
  final Future<void> Function(String phone) onCall;
  final VoidCallback onEdit;

  /// Null unless the patient saved a usable `http(s)` map link.
  final VoidCallback? onDirections;

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  /// The design keeps one provider's drawer open at a time (`openId`); here it
  /// is per-card, which behaves the same from the patient's side.
  bool _filesOpen = false;
  bool _busy = false;

  CareProvider get provider => widget.provider;

  /// Saves the picked bytes into the encrypted vault, then links the path.
  /// Bytes never land in the database and never touch plaintext disk.
  Future<void> _attach() async {
    if (_busy) return;
    final c = AppScope.of(context).strings.care;
    final picked = await pickFileAttach();
    if (picked == null || picked.bytes == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final store = ref.read(userFileStoreProvider);
      final path = await store.save(picked.name ?? 'attachment', picked.bytes!);
      await ref.read(profileDataSourceProvider).addProviderFile(provider.id, path);
      ref.invalidate(careProviderFilesProvider(provider.id));
      if (mounted) setState(() => _filesOpen = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.care_save_failed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detach(String path) async {
    await ref.read(profileDataSourceProvider).removeProviderFile(provider.id, path);
    ref.invalidate(careProviderFilesProvider(provider.id));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final files = ref.watch(careProviderFilesProvider(provider.id)).valueOrNull ?? const <String>[];
    final c = s.strings.care;
    final phone = provider.phone;
    final phones = [provider.phone, provider.phone2].where((p) => p != null && p.isNotEmpty).join(' · ');

    Widget line(IconData icon, String text, {bool ltr = false, bool italic = false}) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 12, color: T.fg3),
            ),
            const SizedBox(width: 4),
            // Flexible, not Expanded: an LTR run (a phone number, an email) in
            // an RTL card would otherwise be stranded at the far end of a
            // full-width box instead of sitting against its icon.
            Flexible(
              child: Text(text,
                  textDirection: ltr ? TextDirection.ltr : null,
                  style: Typo.bodySm(ar: s.rtl).copyWith(
                    fontSize: FS.xs,
                    color: T.fg3,
                    height: 1.45,
                    fontStyle: italic ? FontStyle.italic : null,
                  )),
            ),
          ]),
        );

    return PCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: T.ink100, shape: BoxShape.circle),
            child: Icon(careTypeIcon(provider.type), size: 22, color: T.fg3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 7, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(provider.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(careTypeIcon(provider.type), size: 11, color: T.fg3),
                    const SizedBox(width: 4),
                    Text(careTypeLabel(c, provider.type),
                        style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              if (provider.specialty case final String v when v.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(v, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ),
              if (provider.placeLine case final String v?) line(LucideIcons.mapPin, v),
              if (widget.onDirections != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Pressable(
                    onTap: widget.onDirections,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.navigation, size: 12, color: s.accent.d),
                      const SizedBox(width: 4),
                      Text(c.care_directions,
                          style: Typo.bodySm(ar: s.rtl)
                              .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, color: s.accent.d)),
                    ]),
                  ),
                ),
              if (phones.isNotEmpty) line(LucideIcons.phone, phones, ltr: true),
              if (provider.email case final String v when v.isNotEmpty) line(LucideIcons.mail, v, ltr: true),
              if (provider.notes case final String v when v.isNotEmpty) line(LucideIcons.stickyNote, v, italic: true),
            ]),
          ),
          const SizedBox(width: 6),
          // The design swapped remove for edit here: a provider's number or
          // clinic changes far more often than the provider does, and removing
          // and re-adding them lost their attached files. Removal now lives
          // inside the edit sheet, behind a confirm.
          Semantics(
            button: true,
            label: c.care_edit,
            child: RoundBtn(icon: LucideIcons.pencil, ghost: true, iconSize: 16, onTap: widget.onEdit),
          ),
        ]),
        // Collapsed, the card previews what is attached: a 64pt strip that
        // opens the viewer at whichever file was tapped. It gives way to the
        // full gallery once the drawer is open.
        if (files.isNotEmpty && !_filesOpen) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => SizedBox(
                width: 64,
                child: VaultAttachmentThumb(
                  path: files[i],
                  compact: true,
                  height: 64,
                  onOpen: () => VaultFileViewer.openAll(context, paths: files, index: i, title: provider.name),
                ),
              ),
            ),
          ),
        ],
        // The design always shows a Call/Message pair; Message has nowhere to
        // go here, so Call appears only when there is a number to dial, and
        // Files sits beside it exactly as the design places it.
        const SizedBox(height: 14),
        Row(children: [
          if (phone != null && phone.isNotEmpty)
            Expanded(
              child: PButton(
                c.care_call,
                icon: LucideIcons.phone,
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                accent: s.accent,
                ar: s.rtl,
                block: true,
                onTap: () => widget.onCall(phone),
              ),
            ),
          if (phone != null && phone.isNotEmpty) const SizedBox(width: 8),
          // `block` stretches to infinity, which a bare Row child cannot be
          // given — so the sole button flexes instead.
          Builder(builder: (context) {
            // Three states, as the design has them: nothing attached goes
            // straight to the picker; attached collapses/expands the drawer.
            final files0 = PButton(
              files.isEmpty
                  ? c.care_attach_file
                  : _filesOpen
                      ? c.care_files_done
                      : c.care_manage_files,
              icon: files.isEmpty
                  ? LucideIcons.paperclip
                  : _filesOpen
                      ? LucideIcons.check
                      : LucideIcons.pencil,
              variant: BtnVariant.secondary,
              size: BtnSize.sm,
              accent: s.accent,
              ar: s.rtl,
              block: phone == null || phone.isEmpty,
              onTap: files.isEmpty ? _attach : () => setState(() => _filesOpen = !_filesOpen),
            );
            return phone == null || phone.isEmpty ? Expanded(child: files0) : files0;
          }),
        ]),
        if (_filesOpen) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: T.ink100),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(LucideIcons.paperclip, size: 13, color: T.fg3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.care_files_head,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, color: T.fg3)),
            ),
            if (_busy)
              const SizedBox(width: 16, height: 16, child: Spinner(size: 16))
            else
              PButton(
                c.care_attach,
                icon: LucideIcons.plus,
                variant: BtnVariant.ghost,
                size: BtnSize.sm,
                accent: s.accent,
                ar: s.rtl,
                onTap: _attach,
              ),
          ]),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 10),
            VaultAttachmentGallery(
              paths: files,
              height: 150,
              title: provider.name,
              onAdd: _attach,
              onRemove: (i) => _detach(files[i]),
              addLabel: c.care_attach_add,
            ),
          ],
        ],
      ]),
    );
  }
}

class _CareSearchField extends StatelessWidget {
  const _CareSearchField({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.md),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.sm),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: const Icon(LucideIcons.search, size: 17, color: T.fg4),
        prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 40),
        suffixIcon: controller.text.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: T.ink100, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.x, size: 13, color: T.fg3),
                  ),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        border: border(T.border),
        enabledBorder: border(T.border),
        focusedBorder: border(s.accent.main),
      ),
    );
  }
}

/// Outline filter chip — the care-team variant (accent-50 fill when on), not
/// the solid-accent [BChip] used by records and the map.
class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.icon, required this.label, required this.active, required this.onTap, this.tall = false});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// The add-sheet's picker sits at 38; the filter row at 32.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        height: tall ? 38 : 32,
        padding: EdgeInsets.symmetric(horizontal: tall ? 13 : 11),
        decoration: BoxDecoration(
          color: active ? s.accent.bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: active ? s.accent.main : T.border, width: tall ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: tall ? 15 : 13, color: active ? s.accent.d : T.fg3),
          const SizedBox(width: 5),
          Text(label,
              style: Typo.body(ar: s.rtl).copyWith(
                fontSize: tall ? FS.sm : FS.xs,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? s.accent.d : (tall ? T.fg2 : T.fg3),
              )),
        ]),
      ),
    );
  }
}

/// "Add a provider" (`home.jsx` CareTeamScreen's `SettingsSheet`).
///
/// Only the name is required; everything else is optional free text. Pops
/// `true` once the row is written so the caller can refresh and confirm.
class AddCareProviderSheet extends ConsumerStatefulWidget {
  const AddCareProviderSheet({super.key, this.provider});

  /// Non-null puts the sheet in edit mode: the fields arrive filled, the
  /// button says "Save changes", and a remove action appears at the bottom.
  final CareProvider? provider;

  @override
  ConsumerState<AddCareProviderSheet> createState() => _AddCareProviderSheetState();
}

class _AddCareProviderSheetState extends ConsumerState<AddCareProviderSheet> {
  CareProviderType _type = CareProviderType.doctor;
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController();
  final _email = TextEditingController();
  final _clinic = TextEditingController();
  final _address = TextEditingController();
  final _mapUrl = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  /// Second stage of removal — the design asks before it deletes.
  bool _confirmDelete = false;

  CareProvider? get _editing => widget.provider;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    if (p == null) return;
    _type = p.type;
    _name.text = p.name;
    _specialty.text = p.specialty ?? '';
    _phone.text = p.phone ?? '';
    _phone2.text = p.phone2 ?? '';
    _email.text = p.email ?? '';
    _clinic.text = p.clinic ?? '';
    _address.text = p.address ?? '';
    _mapUrl.text = p.mapUrl ?? '';
    _notes.text = p.notes ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _specialty, _phone, _phone2, _email, _clinic, _address, _mapUrl, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// `true` once what the patient typed stops looking like a link at all. An
  /// empty field is fine — the whole field is optional.
  bool get _mapUrlLooksWrong {
    final v = _mapUrl.text.trim();
    if (v.isEmpty) return false;
    final uri = Uri.tryParse(v);
    return uri == null || !uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https');
  }

  Future<void> _pasteMapUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final v = data?.text?.trim();
    if (v == null || v.isEmpty || !mounted) return;
    setState(() => _mapUrl.text = v);
  }

  Future<void> _delete() async {
    if (_saving) return;
    final p = _editing;
    final userId = ref.read(currentUserIdProvider);
    if (p == null || userId == null) {
      _fail();
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(removeCareProviderUseCaseProvider).execute(userId: userId, providerId: p.id);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _saving = false);
    _fail();
  }

  Future<void> _save() async {
    if (_saving) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      // Signed out there is no profile to hang the row on. Say so rather than
      // letting the button look broken.
      _fail();
      return;
    }
    setState(() => _saving = true);
    final editing = _editing;
    // Arabic-Indic digits normalize on the way in, as everywhere else a phone
    // number is captured (FR-213).
    final result = editing == null
        ? await ref.read(addCareProviderUseCaseProvider).execute(
              userId: userId,
              type: _type,
              name: _name.text,
              specialty: _specialty.text,
              phone: normalizeArabicNumerals(_phone.text),
              phone2: normalizeArabicNumerals(_phone2.text),
              email: _email.text,
              clinic: _clinic.text,
              address: _address.text,
              mapUrl: _mapUrl.text,
              notes: _notes.text,
            )
        : await ref.read(updateCareProviderUseCaseProvider).execute(
              userId: userId,
              provider: editing,
              type: _type,
              name: _name.text,
              specialty: _specialty.text,
              phone: normalizeArabicNumerals(_phone.text),
              phone2: normalizeArabicNumerals(_phone2.text),
              email: _email.text,
              clinic: _clinic.text,
              address: _address.text,
              mapUrl: _mapUrl.text,
              notes: _notes.text,
            );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _saving = false);
    _fail();
  }

  void _fail() => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppScope.of(context).strings.care.care_save_failed)),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.care;
    // Places and people label the same two fields differently.
    final place = _type.isPlace;
    final ready = _name.text.trim().isNotEmpty && !_saving;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(children: [
            Expanded(
                child: Text(_editing == null ? c.care_add_title : c.care_edit_title,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, sheetBottomInset(context, base: 32)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(c.care_add_note, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
              const SizedBox(height: 16),
              _Eyebrow(c.care_f_type, s: s),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in CareProviderType.values)
                  _TypeChip(
                    icon: careTypeIcon(t),
                    label: careTypeLabel(c, t),
                    active: _type == t,
                    tall: true,
                    onTap: () => setState(() => _type = t),
                  ),
              ]),
              const SizedBox(height: 18),
              _Field(
                label: c.care_f_name,
                controller: _name,
                hint: place ? c.care_ph_name_place : c.care_ph_name_person,
                autofocus: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _Field(
                label: place ? c.care_f_services : c.care_f_specialty,
                controller: _specialty,
                hint: place ? c.care_ph_services : c.care_ph_specialty,
              ),
              const SizedBox(height: 18),
              _Eyebrow(c.care_s_contact, s: s),
              const SizedBox(height: 10),
              _Field(label: c.care_f_phone, controller: _phone, phone: true),
              const SizedBox(height: 14),
              _Field(label: c.care_f_phone2, controller: _phone2, hint: c.care_ph_phone2, phone: true),
              const SizedBox(height: 14),
              _Field(
                label: c.care_f_email,
                controller: _email,
                hint: 'doctor@clinic.eg',
                ltr: true,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _Eyebrow(place ? c.care_s_location : c.care_s_clinic, s: s),
              const SizedBox(height: 10),
              _Field(
                label: place ? c.care_f_branch : c.care_f_clinic,
                controller: _clinic,
                hint: c.care_ph_clinic,
              ),
              const SizedBox(height: 14),
              _Field(label: c.care_f_address, controller: _address, hint: c.care_ph_address, lines: 2),
              const SizedBox(height: 14),
              // A map link the patient pastes from their maps app. Paste, not
              // a picker: the design's own hint is "Share -> Copy link".
              _MapLinkField(
                controller: _mapUrl,
                onPaste: _pasteMapUrl,
                onChanged: () => setState(() {}),
                looksWrong: _mapUrlLooksWrong,
              ),
              const SizedBox(height: 14),
              _Field(label: c.care_f_notes, controller: _notes, hint: c.care_ph_notes, lines: 2),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: PButton(
                    s.strings.common.cancel,
                    variant: BtnVariant.secondary,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PButton(
                    _editing == null ? c.care_save : c.care_save_changes,
                    variant: BtnVariant.primary,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: ready ? _save : null,
                  ),
                ),
              ]),
              // Removal only exists in edit mode, and only behind a confirm —
              // the row's attached files go with it.
              if (_editing != null) ...[
                if (!_confirmDelete)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: PButton(
                      c.care_delete,
                      icon: LucideIcons.trash2,
                      variant: BtnVariant.ghost,
                      block: true,
                      color: T.danger,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: _saving ? null : () => setState(() => _confirmDelete = true),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: T.dangerBg,
                      borderRadius: BorderRadius.circular(T.rLg),
                      border: Border.all(color: T.danger),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(c.care_delete_q(_name.text.trim()),
                          style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                      const SizedBox(height: 4),
                      Text(c.care_delete_h,
                          style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, color: T.fg2, height: 1.5)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: PButton(
                            c.care_keep,
                            variant: BtnVariant.secondary,
                            size: BtnSize.sm,
                            accent: s.accent,
                            ar: s.rtl,
                            onTap: _saving ? null : () => setState(() => _confirmDelete = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PButton(
                            c.care_remove,
                            variant: BtnVariant.primary,
                            size: BtnSize.sm,
                            color: T.danger,
                            accent: s.accent,
                            ar: s.rtl,
                            onTap: _saving ? null : _delete,
                          ),
                        ),
                      ]),
                    ]),
                  ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Uppercase tracked section label (`letter-spacing: 0.16em`).
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label, {required this.s});
  final String label;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(), style: Typo.eyebrow(T.fg3, ar: s.rtl));
}

/// Labelled `.b-input`, single- or multi-line.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.lines = 1,
    this.ltr = false,
    this.phone = false,
    this.autofocus = false,
    this.keyboard,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int lines;
  final bool ltr;
  final bool phone;
  final bool autofocus;
  final TextInputType? keyboard;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: lines,
        minLines: lines,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        // Phone numbers are always LTR, whatever the UI language.
        textDirection: ltr || phone ? TextDirection.ltr : null,
        keyboardType: keyboard ?? (phone ? TextInputType.phone : TextInputType.text),
        style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.sm),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: border(T.border),
          enabledBorder: border(T.border),
          focusedBorder: border(s.accent.main),
        ),
      ),
    ]);
  }
}

/// The map-link row: a pin, the URL, and a Paste button sitting inside the
/// field, with the design's help text underneath until something is typed.
class _MapLinkField extends StatelessWidget {
  const _MapLinkField({
    required this.controller,
    required this.onPaste,
    required this.onChanged,
    required this.looksWrong,
  });
  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onChanged;
  final bool looksWrong;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.care;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(c.care_f_map, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      const SizedBox(height: 6),
      Stack(alignment: AlignmentDirectional.centerEnd, children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          style: Typo.body(ar: s.rtl),
          decoration: InputDecoration(
            hintText: c.care_ph_map,
            prefixIcon: const Icon(LucideIcons.mapPinned, size: 16, color: T.fg3),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            // Room for the Paste button so the text never runs under it.
            contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 14, 82, 14),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: PButton(
            c.care_paste,
            icon: LucideIcons.clipboardPaste,
            variant: BtnVariant.ghost,
            size: BtnSize.sm,
            accent: s.accent,
            ar: s.rtl,
            onTap: onPaste,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      if (looksWrong)
        Text(c.care_map_bad, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, color: T.danger))
      else if (controller.text.trim().isEmpty)
        Text(c.care_map_help, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, height: 1.5)),
    ]);
  }
}
