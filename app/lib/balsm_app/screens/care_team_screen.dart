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
import '../widgets/phone_field.dart';
import '../widgets/vault_file_viewer.dart';
import '../widgets/photo_attach.dart';
import '../routes.dart';
import '../tokens.dart';
import 'care_import_sheet.dart';
import 'profile_subscreens.dart';
import '../storage_target.dart';
import '../widgets/data_loc_pill.dart';

/// Care team (`home.jsx` `CareTeamScreen` + its "Add a provider" sheet).
///
/// The design seeds a roster of sample doctors; this screen shows only what
/// the patient entered. Who treats a patient is sensitive, so the rows are
/// on-device PHI like the rest of the profile — nothing is fabricated and
/// nothing leaves the device.
///
void openCareTeam(BuildContext context) => pushSubScreen(context, (s) => const CareTeamScreen());

/// One provider's attachments — vault files and links together, oldest first.
final careProviderFilesProvider = StreamProvider.autoDispose.family<List<CareProviderFile>, CareProviderId>((ref, id) {
  return ref.watch(careProvidersDataSourceProvider).watchFiles(id);
});

/// The patient's care team, newest write reflected immediately.
///
/// Scoped to the active health profile, so it empties on sign-out and
/// re-resolves for a dependant profile when P00X re-points
/// [currentProfileIdProvider].
final careTeamProvider = StreamProvider.autoDispose<List<CareProvider>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const <CareProvider>[]);
  return ref.watch(careProvidersDataSourceProvider).watchAll(scope: profileId);
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
    _importedTimer?.cancel();
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

  /// How many rows the last import created, for the inline banner. Zero hides
  /// it. `home.jsx` clears it after 5s rather than leaving it on the screen.
  int _imported = 0;
  Timer? _importedTimer;

  void _showImported(int n) {
    setState(() => _imported = n);
    _importedTimer?.cancel();
    _importedTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _imported = 0);
    });
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

  /// Import from the phone's contacts. Returns the number of rows created, or
  /// -1 when the patient chose to type one in by hand instead.
  Future<void> _import() async {
    final result = await showAppSheet<int>(
      context,
      size: SheetSize.lg,
      builder: (_) => const CareImportSheet(),
    );
    if (!mounted || result == null) return;
    if (result == -1) return _add();
    if (result <= 0) return;

    ref.invalidate(careTeamProvider);
    // Clear any filter, so rows just added are actually in view.
    setState(() {
      _typeFilter = null;
      _query.clear();
    });
    _showImported(result);
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
      trailing: const DataLocPill(category: DataCategory.care),
      // `home.jsx` routes the FAB through the phone's contacts: most of a care
      // team is already in the address book, so typing one in by hand is the
      // fallback, reachable from inside the import sheet.
      floating: _CareFab(onTap: _import),
      // FR-509: sign-in and foreground are handled by the shell; this is the
      // explicit user refresh. The list itself keeps reading from drift, so the
      // rows are already on screen — this only reconciles with the cloud.
      onRefresh: () async {
        final profileId = ref.read(currentProfileIdProvider);
        if (profileId == null) return;
        await ref.read(careTeamSyncServiceProvider).sync(profileId);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
          child: Text(c.care_intro, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
        ),
        if (_imported > 0) _ImportedBanner(s: s, count: _imported),
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

/// Confirmation that an import landed, and a nudge to fill in what the address
/// book could not supply (`home.jsx`, the `imported` block).
///
/// An inline banner rather than a toast: it names an action the patient takes on
/// rows that are now on screen, and a toast is gone before they can read it.
class _ImportedBanner extends StatelessWidget {
  const _ImportedBanner({required this.s, required this.count});
  final PatientAppState s;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: T.successBg, borderRadius: BorderRadius.circular(T.rLg)),
          child: Semantics(
            liveRegion: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.circleCheck, size: 17, color: T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.strings.care.care_import_banner('$count'),
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1, height: 1.4),
                ),
              ),
            ]),
          ),
        ),
      );
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
      label: s.strings.care.care_import_fab,
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
  CareProvider get provider => widget.provider;

  /// Bytes never land in the database and never touch plaintext disk.

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final files = ref.watch(careProviderFilesProvider(provider.id)).valueOrNull ?? const <CareProviderFile>[];
    // Only vault files have a thumbnail; a link is not something to preview.
    final thumbs = [
      for (final f in files)
        if (!f.isLink) f.locator
    ];
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
          // One node, naming who is being edited — what a screen reader user
          // needs when several cards are open. An outer generic "Edit" wrapper
          // used to sit here; it merged into this node, so it only duplicated
          // the word.
          RoundBtn(
              icon: LucideIcons.pencil,
              semanticLabel: '${c.care_edit} ${provider.name}',
              ghost: true,
              iconSize: 16,
              onTap: widget.onEdit),
        ]),
        // The card previews what is attached: a 64pt strip that opens the
        // viewer at whichever file was tapped. Managing them is the edit
        // sheet's job, so there is no drawer for this to give way to.
        if (thumbs.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: thumbs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => SizedBox(
                width: 64,
                child: VaultAttachmentThumb(
                  path: thumbs[i],
                  compact: true,
                  height: 64,
                  onOpen: () => VaultFileViewer.openAll(context, paths: thumbs, index: i, title: provider.name),
                ),
              ),
            ),
          ),
        ],
        // The design shows Call alone: attaching moved into the edit sheet, so
        // the card no longer carries a files button or its drawer.
        if (phone != null && phone.isNotEmpty) ...[
          const SizedBox(height: 14),
          PButton(
            c.care_call,
            icon: LucideIcons.phone,
            variant: BtnVariant.secondary,
            size: BtnSize.sm,
            accent: s.accent,
            ar: s.rtl,
            block: true,
            onTap: () => widget.onCall(phone),
          ),
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

  /// Vault paths attached before the row exists. `home.jsx` keeps them in
  /// `formAtts` and writes them with the provider; add mode has no
  /// [CareProviderId] to file them under until the save returns one, so they
  /// wait here and are linked in [_save].
  ///
  /// Edit mode never uses this — there the id already exists, so a file is
  /// linked the moment it is picked, exactly as the card does it.
  final List<CareProviderFile> _staged = [];

  bool _attaching = false;

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

  /// Files on this provider: the stored set in edit mode, the staged set in add
  /// mode.
  List<CareProviderFile> _files() {
    final p = _editing;
    if (p == null) return _staged;
    return ref.watch(careProviderFilesProvider(p.id)).valueOrNull ?? const <CareProviderFile>[];
  }

  Future<void> _attachFile() async {
    if (_attaching || _saving) return;
    // Ask where from first: Files and Photos are separate pickers on both
    // platforms, and opening the wrong one is a dead end for a patient whose
    // business card is a photo.
    final picked = await pickAttachment(context);
    if (picked == null || !mounted) return;

    // A link carries no bytes and never touches the vault.
    if (picked.kind == 'url') {
      final url = picked.url?.trim() ?? '';
      if (!isStorableLink(url)) {
        _fail();
        return;
      }
      await _attachLink(url);
      return;
    }
    if (picked.bytes == null) return;

    setState(() => _attaching = true);
    try {
      final path = await ref.read(userFileStoreProvider).save(picked.name ?? 'attachment', picked.bytes!);
      await _record(CareProviderFile.file(path));
    } catch (_) {
      if (mounted) _fail();
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _attachLink(String url) async {
    setState(() => _attaching = true);
    try {
      await _record(CareProviderFile.link(url));
    } catch (_) {
      if (mounted) _fail();
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  /// Stage it in add mode, write it in edit mode.
  Future<void> _record(CareProviderFile attachment) async {
    final p = _editing;
    if (p == null) {
      if (!_staged.contains(attachment)) _staged.add(attachment);
      return;
    }
    final dao = ref.read(careProvidersDataSourceProvider);
    if (attachment.isLink) {
      await dao.putLink(p.id, attachment.locator);
    } else {
      await dao.putFile(p.id, attachment.locator);
    }
    ref.invalidate(careProviderFilesProvider(p.id));
  }

  Future<void> _detachFile(CareProviderFile attachment) async {
    final p = _editing;
    if (p == null) {
      setState(() => _staged.remove(attachment));
      return;
    }
    await ref.read(careProvidersDataSourceProvider).deleteFile(p.id, attachment.locator);
    ref.invalidate(careProviderFilesProvider(p.id));
  }

  Future<void> _openLink(String url) async {
    // Only ever what `isStorableLink` let through, and always externally: a
    // pasted URL is never rendered inside the app.
    if (!isStorableLink(url)) return;
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (mounted) _fail();
    }
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
      // Add mode: the row only just got an id, so anything attached while
      // filling the form is filed under it now.
      if (editing == null && _staged.isNotEmpty) {
        final dao = ref.read(careProvidersDataSourceProvider);
        for (final a in _staged) {
          if (a.isLink) {
            await dao.putLink(result.value.id, a.locator);
          } else {
            await dao.putFile(result.value.id, a.locator);
          }
        }
        if (!mounted) return;
      }
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
    final files = _files();
    final vaultFiles = [
      for (final a in files)
        if (!a.isLink) a.locator
    ];

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
            RoundBtn(
                icon: LucideIcons.x,
                semanticLabel: s.strings.common.a11y_close,
                ghost: true,
                iconSize: 18,
                onTap: () => Navigator.pop(context)),
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
              const SizedBox(height: 16),
              _Eyebrow(c.care_s_contact, s: s),
              const SizedBox(height: 14),
              _LabelledPhone(label: c.care_f_phone, controller: _phone, s: s),
              const SizedBox(height: 14),
              _LabelledPhone(label: c.care_f_phone2, controller: _phone2, s: s, hint: c.care_ph_phone2),
              const SizedBox(height: 14),
              _Field(
                label: c.care_f_email,
                controller: _email,
                hint: 'doctor@clinic.eg',
                ltr: true,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _Eyebrow(place ? c.care_s_location : c.care_s_clinic, s: s),
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              // Business card & files. The design attaches here, not only from
              // the roster card — a business card is something you have in hand
              // while you are typing the provider in.
              Row(children: [
                Expanded(child: _Eyebrow(c.care_files_head, s: s)),
                if (_attaching)
                  const SizedBox(width: 20, height: 20, child: Spinner(size: 20))
                else
                  PButton(
                    c.care_attach,
                    icon: LucideIcons.plus,
                    variant: BtnVariant.ghost,
                    size: BtnSize.sm,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _attachFile,
                  ),
              ]),
              const SizedBox(height: 10),
              if (files.isEmpty)
                _AttachEmpty(s: s, onTap: _attaching ? null : _attachFile)
              else ...[
                if (vaultFiles.isNotEmpty)
                  VaultAttachmentGallery(
                    paths: vaultFiles,
                    height: 150,
                    title: _name.text.trim().isEmpty ? c.care_files_head : _name.text.trim(),
                    onAdd: _attachFile,
                    onRemove: (i) => _detachFile(CareProviderFile.file(vaultFiles[i])),
                    addLabel: c.care_attach_add,
                  ),
                // Links sit under the gallery as their own rows: there is no
                // thumbnail to render, and nothing is fetched to make one.
                for (final link in files.where((a) => a.isLink)) ...[
                  const SizedBox(height: 8),
                  _LinkRow(
                    s: s,
                    url: link.locator,
                    onOpen: () => _openLink(link.locator),
                    onRemove: _saving ? null : () => _detachFile(link),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: PButton(
                    s.strings.common.cancel,
                    variant: BtnVariant.secondary,
                    large: true,
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
                    large: true,
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

/// One attached link. Shows the host rather than the whole URL — a maps or
/// drive link is unreadable at full length and the host is what tells the
/// patient where it goes.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.s, required this.url, required this.onOpen, required this.onRemove});
  final PatientAppState s;
  final String url;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? url;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rMd),
        border: Border.all(color: T.border),
      ),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${s.strings.care.care_link_opens} $host',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTapTarget),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                  child: Row(children: [
                    const Icon(LucideIcons.link, size: 16, color: T.fg3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
                      ),
                    ),
                    const Icon(LucideIcons.externalLink, size: 14, color: T.fg3),
                  ]),
                ),
              ),
            ),
          ),
        ),
        RoundBtn(
            icon: LucideIcons.x,
            semanticLabel: '${s.strings.care.care_link_remove} $host',
            ghost: true,
            iconSize: 15,
            onTap: onRemove),
      ]),
    );
  }
}

/// Nothing attached yet: a dashed invitation rather than an empty gallery, so
/// the row does not look broken before the patient has added anything.
class _AttachEmpty extends StatelessWidget {
  const _AttachEmpty({required this.s, required this.onTap});
  final PatientAppState s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = s.strings.care;
    return Semantics(
      button: true,
      label: '${c.care_attach_empty}. ${c.care_attach_empty_h}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: DashedBorder(
          radius: T.rLg,
          strokeWidth: 1.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              const Icon(LucideIcons.paperclip, size: 16, color: T.fg3),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.care_attach_empty,
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(c.care_attach_empty_h, style: Typo.meta(ar: s.rtl)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A [PhoneField] under the same label the other fields use, so the form reads
/// as one column.
class _LabelledPhone extends StatelessWidget {
  const _LabelledPhone({required this.label, required this.controller, required this.s, this.hint});
  final String label;
  final TextEditingController controller;
  final PatientAppState s;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        const SizedBox(height: 6),
        PhoneField(controller: controller, hint: hint ?? kPhoneHintExample),
      ]);
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
    this.autofocus = false,
    this.keyboard,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int lines;
  final bool ltr;
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
        textDirection: ltr ? TextDirection.ltr : null,
        keyboardType: keyboard ?? TextInputType.text,
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
      // Paste rides in the decoration, not in a Stack over it. A Stack sizes to
      // its children, and a TextField given loose constraints shrink-wraps to
      // its hint — which put the button in the middle of the field, on top of
      // the text. As a suffix the field also reserves the room itself.
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        keyboardType: TextInputType.url,
        textDirection: TextDirection.ltr,
        style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
        decoration: InputDecoration(
          hintText: c.care_ph_map,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.sm),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: const Icon(LucideIcons.mapPinned, size: 16, color: T.fg3),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: kMinTapTarget),
          // IntrinsicWidth, not a bare Padding: [MinTapTarget] centres its
          // child, and a Center under loose constraints expands to fill them —
          // so the suffix took the whole field, the button floated to the
          // middle of it and the content area collapsed to nothing. Sizing the
          // suffix to the button's own width pins it back to the edge.
          suffixIcon: IntrinsicWidth(
            child: Padding(
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
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
          // The same outline every other field in this form carries; without
          // it Material falls back to an underline and the prefix icon sits
          // outside the box.
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ),
      const SizedBox(height: 6),
      if (looksWrong)
        Text(c.care_map_bad, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, color: T.danger))
      else if (controller.text.trim().isEmpty)
        Text(c.care_map_help, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, height: 1.5)),
    ]);
  }
}
