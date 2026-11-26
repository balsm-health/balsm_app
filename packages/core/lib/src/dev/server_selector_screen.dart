import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../flags/feature_flags.dart';
import '../kit/tokens.dart';
import '../network/balsm_api_controller.dart';
import 'dev_config_store.dart';
import 'dev_console_colors.dart';
import 'dev_console_state.dart';
import 'dev_diagnostics.dart';
import 'dev_log_buffer.dart';
import 'server_url.dart';

// Developer console only.
const _badgeRadius = 3.0;
// Developer console only.
const _chipRadius = 5.0;
// Developer console only.
const _iconTileRadius = 8.0;
// Developer console only.
const _badgeFontSize = 9.0;
// Developer console only: the monospaced log lines.
const _monoFontSize = 10.5;
// Developer console only.
const _toggleAnimation = Duration(milliseconds: 180);

// Dark "terminal" chrome from the Dev Config design (claude.ai/design · Balsm App).
const _kMono = 'monospace';

/// Dev Config — full port of the design's three-tab overlay
/// (Environment · Logs · Report bug). Reachable in EVERY flavor (shake gesture);
/// server SWITCHING and log EXPORT are dev/staging only. In prod this renders
/// read-only diagnostics with the switcher hidden (a mis-pointed prod build
/// could leak PHI to the wrong backend).
///
/// The connection check, the bug report's severity and screenshot choice, and
/// the store / log changes it redraws on live in providers
/// (`dev_console_state.dart`); the rest is view state of this screen.
class ServerSelectorScreen extends ConsumerStatefulWidget {
  const ServerSelectorScreen({required this.controller, super.key, this.screenshot});
  final BalsmApiController controller;

  /// PNG of the app as it was just before Dev Config opened — what the Report
  /// bug tab shows and can attach. Null when nothing was captured.
  final Uint8List? screenshot;

  @override
  ConsumerState<ServerSelectorScreen> createState() => _ServerSelectorScreenState();
}

class _ServerSelectorScreenState extends ConsumerState<ServerSelectorScreen> {
  final DevConfigStore _store = DevConfigStore.instance;
  final DevLogBuffer _buffer = DevLogBuffer.instance;

  String _tab = 'env'; // env | logs | bug
  bool _loading = false;

  // Environment tab
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _editNameCtrl = TextEditingController();
  final _editUrlCtrl = TextEditingController();
  bool _addingCustom = false;
  String? _editingId;
  ServerPreset? _pendingProd;

  // Logs tab
  String? _sendStatus; // null | sending | sent | error

  // Bug tab
  final _bugTitleCtrl = TextEditingController();
  final _bugStepsCtrl = TextEditingController();
  bool _reportCopied = false;
  String? _bugSendStatus; // null | sending | sent | error

  /// Where requests go now — shown, probed and reported.
  String get _currentBaseUrl => widget.controller.client.baseUrl;

  /// The server chosen — what decides which row is selected. Differs from
  /// [_currentBaseUrl] for Local, whose `localhost` is rewritten to the machine
  /// actually serving it.
  String get _selectedBaseUrl => widget.controller.selectedBaseUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
  }

  @override
  void dispose() {
    // Shared instance — outlives this screen, so it is not disposed here.
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _editNameCtrl.dispose();
    _editUrlCtrl.dispose();
    _bugTitleCtrl.dispose();
    _bugStepsCtrl.dispose();
    super.dispose();
  }

  String _activeLabel(FlavorConfig cfg) {
    for (final p in cfg.servers) {
      if (p.apiBaseUrl == _selectedBaseUrl) return p.label;
    }
    for (final e in _store.savedEnvs) {
      if (e.url == _selectedBaseUrl) return e.name;
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    // Redraw on any change to the saved envs, flags or logs.
    ref.watch(devConsoleChangesProvider);
    final cfg = FlavorConfig.current;
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          children: [
            _header(cfg),
            _tabStrip(),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.hueBlue,
                backgroundColor: AppColors.ink100,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 52),
                children: switch (_tab) {
                  'logs' => _logsBody(cfg),
                  'bug' => _bugBody(cfg),
                  _ => _envBody(cfg),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(FlavorConfig cfg) {
    final label = _activeLabel(cfg);
    final es = _EnvStyle.of(label);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 12),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DevConsoleColors.background,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.terminal, size: 20, color: DevConsoleColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dev Config',
                  style: TextStyle(
                    fontSize: FontSizes.subheadSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'balsm-patient · internal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: _kMono,
                          fontSize: FontSizes.micro,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _EnvChip(label, es),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  // ── Tab strip ───────────────────────────────────────────────────────────────
  Widget _tabStrip() {
    final err = _buffer.errorCount;
    final tabs = <List<Object>>[
      ['env', Icons.dns_outlined, 'Environment'],
      ['logs', Icons.subject, if (err > 0) 'Logs · $err err' else 'Logs'],
      ['bug', Icons.bug_report_outlined, 'Report bug'],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.ink100),
          bottom: BorderSide(color: AppColors.ink100),
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final id = t[0] as String;
          final on = _tab == id;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab = id),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: on ? AppColors.hueBlue : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t[1] as IconData, size: 14, color: on ? AppColors.hueBlue : AppColors.textTertiary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        t[2] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: FontSizes.bodySm,
                          fontWeight: FontWeight.w600,
                          color: on ? AppColors.hueBlue : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══ ENVIRONMENT TAB ═════════════════════════════════════════════════════════
  List<Widget> _envBody(FlavorConfig cfg) {
    final canSwitch = cfg.serverSwitchingEnabled;
    return canSwitch ? _switcherBody(cfg) : _readOnlyBody(cfg);
  }

  List<Widget> _switcherBody(FlavorConfig cfg) => [
        const _Eyebrow('Backend'),
        _HealthRow(baseUrl: _currentBaseUrl),
        ...cfg.servers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _presetCard(p, active: _selectedBaseUrl == p.apiBaseUrl, onTap: () => _onPresetTap(p)),
          ),
        ),
        if (_store.savedEnvs.isNotEmpty) ...[
          const _SavedHeader(),
          ..._store.savedEnvs.map(_savedEnvTile),
        ],
        if (_addingCustom) _customForm() else _addCustomButton(),
        if (_pendingProd case final pendingProd?) _prodConfirm(pendingProd),
        _featureFlags(),
        _appFlags(),
        _buildCard(cfg),
      ];

  List<Widget> _readOnlyBody(FlavorConfig cfg) {
    final active = cfg.servers.firstWhere(
      (p) => p.apiBaseUrl == _selectedBaseUrl,
      orElse: () => ServerPreset(label: _activeLabel(cfg), apiBaseUrl: _currentBaseUrl),
    );
    return [
      const _Eyebrow('Backend'),
      _HealthRow(baseUrl: _currentBaseUrl),
      _presetCard(active, active: true),
      const SizedBox(height: 12),
      const _ReadOnlyNote(),
      _buildCard(cfg),
    ];
  }

  Widget _savedEnvTile(SavedEnv se) {
    final active = _selectedBaseUrl == se.url;
    final editing = _editingId == se.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _select(ServerPreset(label: se.name, apiBaseUrl: se.url)),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: active ? AppColors.ink50 : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: active ? AppColors.ink600 : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: AppColors.ink600, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          se.name,
                          style: TextStyle(
                            fontSize: FontSizes.description,
                            fontWeight: FontWeight.w700,
                            color: active ? DevConsoleColors.panel : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          se.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow, color: AppColors.ink600),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 4),
                      child: Icon(Icons.check_circle, size: 18, color: AppColors.ink600),
                    ),
                  _TinyBtn('edit', () {
                    setState(() {
                      if (editing) {
                        _editingId = null;
                      } else {
                        _editingId = se.id;
                        _editNameCtrl.text = se.name;
                        _editUrlCtrl.text = se.url;
                      }
                    });
                  }),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _store.deleteSavedEnv(se.id),
                    icon: const Icon(Icons.close, size: 14, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          if (editing) _editForm(se),
        ],
      ),
    );
  }

  Widget _editForm(SavedEnv se) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.ink600, width: 1.5),
        ),
        child: Column(
          children: [
            _MonoField('name', _editNameCtrl),
            const SizedBox(height: 8),
            _MonoField('url', _editUrlCtrl),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _editingId = null),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final n = _editNameCtrl.text.trim();
                    final rawUrl = _editUrlCtrl.text.trim();
                    if (n.isEmpty || rawUrl.isEmpty) return;
                    final u = normalizeServerUrl(rawUrl);
                    if (u == null) {
                      _snack('Enter a valid server URL, e.g. http://192.168.1.10:5050');
                      return;
                    }
                    unawaited(_store.updateSavedEnv(se.id, n, u));
                    setState(() => _editingId = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DevConsoleColors.panel,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Preset card ─────────────────────────────────────────────────────────────
  Widget _presetCard(ServerPreset p, {required bool active, VoidCallback? onTap}) {
    final es = _EnvStyle.of(p.label);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: active ? es.bg : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: active ? es.dot : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: es.dot,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(color: es.dot, spreadRadius: 5),
                      BoxShadow(color: es.bg, spreadRadius: 3),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: FontSizes.description,
                        fontWeight: FontWeight.w700,
                        color: active ? es.fg : AppColors.textPrimary,
                      ),
                    ),
                    if (es.isProd) ...[
                      const SizedBox(width: 7),
                      const _LiveBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  p.apiBaseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _kMono,
                    fontSize: FontSizes.eyebrow,
                    color: active ? es.fg : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Icon(Icons.check_circle, size: 19, color: es.dot),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }

  // ── Custom environment (name + url) ─────────────────────────────────────────
  Widget _addCustomButton() => GestureDetector(
        onTap: () => setState(() {
          _addingCustom = true;
          _nameCtrl.clear();
          _urlCtrl.clear();
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.add, size: 16, color: AppColors.textTertiary),
              SizedBox(width: 8),
              Text(
                'Add custom environment',
                style:
                    TextStyle(fontSize: FontSizes.bodySm, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );

  Widget _customForm() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NEW ENVIRONMENT',
              style: TextStyle(
                fontSize: FontSizes.micro,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            _MonoField('name', _nameCtrl, hint: 'My Staging'),
            const SizedBox(height: 8),
            _MonoField('url', _urlCtrl, hint: 'https://api.example.com'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _addingCustom = false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _saveCustom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hueBlue,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Production-switch confirm ──────────────────────────────────────────────
  Widget _prodConfirm(ServerPreset p) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.dangerBackground,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.danger, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Switch to production?',
                        style: TextStyle(
                          fontSize: FontSizes.description,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onDangerBackground,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Real patient data. Real consequences. Any action here is permanent.',
                        style: TextStyle(fontSize: FontSizes.meta, height: 1.5, color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _pendingProd = null),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final t = _pendingProd!;
                      setState(() => _pendingProd = null);
                      unawaited(_select(t));
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Switch anyway'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Feature flags ───────────────────────────────────────────────────────────
  Widget _featureFlags() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const _Eyebrow('Feature flags'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ...kDevFlags.indexed.map((e) => _flagRow(e.$2, first: e.$1 == 0)),
              ],
            ),
          ),
        ],
      );

  Widget _flagRow(DevFlag f, {required bool first}) {
    final on = _store.flag(f.id);
    return GestureDetector(
      onTap: () => _store.setFlag(f.id, !on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: on ? AppColors.hueBlue50 : Colors.transparent,
          border: first ? null : const Border(top: BorderSide(color: AppColors.ink100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.label,
                    style: const TextStyle(
                      fontSize: FontSizes.bodySm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(f.desc, style: const TextStyle(fontSize: FontSizes.eyebrow, color: AppColors.textTertiary)),
                ],
              ),
            ),
            _DcToggle(on: on),
          ],
        ),
      ),
    );
  }

  // ── App feature flags (the real ones: FeatureFlags) ────────────────────────
  // Distinct from the dev toggles above, which only exist on this screen.
  // These are the flags the shipped app reads; a tap forces one on this
  // device, cycling on → off → back to whatever the sources say.
  Widget _appFlags() {
    final flags = FeatureFlags.current;
    if (flags == null || flags.flags.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: flags,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const _Eyebrow('App feature flags'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ...flags.flags.indexed.map((e) => _appFlagRow(flags, e.$2, first: e.$1 == 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appFlagRow(FeatureFlags flags, FeatureFlag f, {required bool first}) {
    final on = flags.isOn(f);
    final forced = flags.overrideOf(f);
    final from = switch (flags.originOf(f)) {
      FlagOrigin.override => 'forced here',
      FlagOrigin.source => 'from ${flags.sourceOf(f) ?? 'last launch'}',
      FlagOrigin.fallback => 'default',
    };
    return GestureDetector(
      onTap: () => flags.setOverride(
        f,
        switch (forced) {
          null => true,
          true => false,
          false => null,
        },
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: forced != null ? AppColors.hueBlue50 : Colors.transparent,
          border: first ? null : const Border(top: BorderSide(color: AppColors.ink100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.label,
                    style: const TextStyle(
                      fontSize: FontSizes.bodySm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${f.key} · $from',
                    style: const TextStyle(fontSize: FontSizes.eyebrow, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            _DcToggle(on: on),
          ],
        ),
      ),
    );
  }

  // ── Build info (dark terminal card) ────────────────────────────────────────
  Widget _buildCard(FlavorConfig cfg) => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DevConsoleColors.background,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '// build',
                style: TextStyle(
                  fontFamily: _kMono,
                  fontSize: FontSizes.eyebrow,
                  fontWeight: FontWeight.w700,
                  color: DevConsoleColors.accent,
                ),
              ),
            ),
            _TermRow('app', cfg.appName),
            _TermRow('brand', cfg.brand.name),
            _TermRow('flavor', cfg.flavor.name),
            _TermRow('server', _currentBaseUrl),
          ],
        ),
      );

  // ══ LOGS TAB ═════════════════════════════════════════════════════════════════
  List<Widget> _logsBody(FlavorConfig cfg) {
    final canExport = cfg.serverSwitchingEnabled; // dev/staging only
    final last = _buffer.lastAt;
    return [
      const _Eyebrow('Summary'),
      Row(
        children: [
          _StatCard('Total', _buffer.total, DevConsoleColors.text),
          const SizedBox(width: 8),
          _StatCard('Errors', _buffer.errorCount, DevConsoleColors.error),
          const SizedBox(width: 8),
          _StatCard('Warnings', _buffer.warnCount, DevConsoleColors.warning),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Last entry: ${last == null ? '—' : _hms(last)}',
        style: const TextStyle(fontSize: FontSizes.eyebrow, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 16),
      const _Eyebrow('Encryption key'),
      _encKeyCard(),
      const SizedBox(height: 4),
      if (!canExport)
        const _ReadOnlyNote()
      else ...[
        const _Eyebrow('Export'),
        _exportButton(
          icon: Icons.lock_outline,
          iconBg: AppColors.hueBlue50,
          iconColor: AppColors.hueBlue,
          title: 'Save encrypted file',
          subtitle: 'AES-256-GCM · .enc.json',
          onTap: _saveEncrypted,
        ),
        const SizedBox(height: 8),
        _sentryButton(cfg),
        const SizedBox(height: 8),
        _clearButton(),
      ],
      const SizedBox(height: 16),
      const _PrivacyNote(),
    ];
  }

  Widget _encKeyCard() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: DevConsoleColors.background, borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(
          children: [
            const Icon(Icons.vpn_key, size: 14, color: DevConsoleColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _store.encKey.isEmpty ? '…' : _store.encKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow, color: DevConsoleColors.text),
              ),
            ),
            _KeyChip(
              'copy',
              () {
                unawaited(Clipboard.setData(ClipboardData(text: _store.encKey)));
                _snack('Key copied');
              },
            ),
            const SizedBox(width: 6),
            // The key travels — into a chat, a ticket, a screenshot of this
            // very card. Regenerating is how one that has travelled stops
            // opening the next export.
            _KeyChip('new', _regenerateKey),
          ],
        ),
      );

  /// Replaces the log-encryption key, after saying what that costs: bundles
  /// already saved keep the key they were encrypted with, and this one will not
  /// open them.
  Future<void> _regenerateKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DevConsoleColors.background,
        title: const Text(
          'New encryption key?',
          style: TextStyle(fontFamily: _kMono, fontSize: FontSizes.description, color: DevConsoleColors.text),
        ),
        content: const Text(
          'Exports you have already saved stay encrypted with the current key — '
          'the new one will not open them. Keep the old key if you still need those.',
          style: TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow, color: AppColors.textTertiary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.regenerateEncKey();
    if (mounted) _snack('New key — it applies to the next export');
  }

  Widget _exportButton({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      _CardButton(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(_iconTileRadius)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: FontSizes.bodySm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: FontSizes.eyebrow, color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      );

  Widget _sentryButton(FlavorConfig cfg) {
    final s = _sendStatus;
    final (bg, ic, icColor, title) = switch (s) {
      'sent' => (AppColors.hueMint50, Icons.check, AppColors.hueMint, 'Sent to Sentry!'),
      'error' => (AppColors.dangerBackground, Icons.warning_amber_rounded, AppColors.danger, 'Failed to send'),
      'sending' => (AppColors.ink50, Icons.sync, AppColors.textSecondary, 'Sending…'),
      _ => (AppColors.ink50, Icons.send, AppColors.textSecondary, 'Send to Sentry'),
    };
    return Opacity(
      opacity: s == 'sending' ? 0.6 : 1,
      child: _exportButton(
        icon: ic,
        iconBg: bg,
        iconColor: icColor,
        title: title,
        subtitle: 'Redacted diagnostic event',
        onTap: s == 'sending' ? () {} : _sendToSentry,
      ),
    );
  }

  Widget _clearButton() => _CardButton(
        border: AppColors.danger,
        onTap: () {
          _buffer.clear();
          _snack('Logs cleared');
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'Clear all logs',
              style: TextStyle(fontSize: FontSizes.bodySm, fontWeight: FontWeight.w600, color: AppColors.danger),
            ),
          ],
        ),
      );

  // ══ BUG REPORT TAB ═══════════════════════════════════════════════════════════
  List<Widget> _bugBody(FlavorConfig cfg) {
    final canSend = cfg.serverSwitchingEnabled; // dev/staging only, like log export
    final shot = widget.screenshot;
    final size = MediaQuery.sizeOf(context);
    final attachShot = ref.watch(bugReportDraftProvider.select((d) => d.attachShot));
    return [
      const _Eyebrow('Screenshot'),
      Container(
        constraints: const BoxConstraints(minHeight: 130),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: shot == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 26, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text(
                      'No screenshot captured',
                      style: TextStyle(fontFamily: _kMono, fontSize: FontSizes.meta, color: AppColors.textHint),
                    ),
                  ],
                ),
              )
            : Opacity(
                opacity: attachShot ? 1 : 0.35,
                child: Image.memory(shot, height: 220, fit: BoxFit.contain, semanticLabel: 'App screenshot'),
              ),
      ),
      if (shot != null) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Expanded(
              child: Text(
                'May show health data — only attach from test accounts.',
                style: TextStyle(fontSize: FontSizes.eyebrow, color: AppColors.textTertiary),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(bugReportDraftProvider.notifier).toggleAttachShot(),
              child: Text(attachShot ? 'Remove' : 'Attach'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      const _FieldLabel('Title'),
      TextField(
        controller: _bugTitleCtrl,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: _inputDeco('Brief description of the bug'),
      ),
      const SizedBox(height: 12),
      const _FieldLabel('Steps to reproduce'),
      TextField(
        controller: _bugStepsCtrl,
        minLines: 3,
        maxLines: 6,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: _inputDeco('1. Go to…\n2. Tap…\n3. Expected: …\n4. Actual: …'),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('Severity'),
      Row(
        children: [
          ...const [
            ['low', 'Low'],
            ['medium', 'Medium'],
            ['high', 'High'],
            ['critical', 'Critical'],
          ].map((s) => Expanded(child: _SeverityButton(id: s[0], label: s[1]))),
        ],
      ),
      const SizedBox(height: 16),
      // Auto context — the design's "context auto-attached" block.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: DevConsoleColors.background, borderRadius: BorderRadius.circular(AppRadii.md)),
        child: DefaultTextStyle(
          style:
              const TextStyle(fontFamily: _kMono, fontSize: _monoFontSize, height: 1.9, color: DevConsoleColors.text),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '// context auto-attached',
                style:
                    TextStyle(color: DevConsoleColors.accent, fontWeight: FontWeight.w700, fontSize: FontSizes.eyebrow),
              ),
              Text('env       ${_activeLabel(cfg)} — $_currentBaseUrl'),
              Text('logs      ${_buffer.total} entries · ${_buffer.errorCount} errors'),
              Text('viewport  ${size.width.round()}×${size.height.round()}'),
              Text('shot      ${shot == null ? 'none' : attachShot ? 'attached' : 'removed'}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (canSend) ...[
        ElevatedButton.icon(
          onPressed: _bugSendStatus == 'sending' ? null : _sendBugReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.hueBlue,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: Icon(
            switch (_bugSendStatus) {
              'sent' => Icons.check,
              'error' => Icons.warning_amber_rounded,
              _ => Icons.send,
            },
            size: 17,
          ),
          label: Text(
            switch (_bugSendStatus) {
              'sending' => 'Sending…',
              'sent' => 'Report sent to Sentry!',
              'error' => 'Failed to send',
              _ => 'Send report to Sentry',
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: _copyReport,
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
        icon: Icon(_reportCopied ? Icons.check : Icons.copy, size: 17),
        label: Text(_reportCopied ? 'Copied to clipboard!' : 'Copy report to clipboard'),
      ),
    ];
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _onPresetTap(ServerPreset p) {
    if (_selectedBaseUrl == p.apiBaseUrl) return;
    if (_EnvStyle.of(p.label).isProd) {
      setState(() => _pendingProd = p);
      return;
    }
    unawaited(_select(p));
  }

  Future<void> _select(ServerPreset preset) async {
    // A result from the previous server would now be read as describing this
    // one — "200 OK" next to a backend nobody has actually reached yet.
    ref.read(serverHealthProvider.notifier).reset();
    setState(() => _loading = true);
    try {
      await widget.controller.reconfigure(preset);
    } on FormatException catch (e) {
      // A preset saved before URL normalization existed (or edited outside
      // this screen) can still carry a schemeless host — surface it instead
      // of an uncaught crash.
      _snack('Cannot use "${preset.apiBaseUrl}" — ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCustom() async {
    final name = _nameCtrl.text.trim();
    final rawUrl = _urlCtrl.text.trim();
    if (name.isEmpty || rawUrl.isEmpty) return;
    final url = normalizeServerUrl(rawUrl);
    if (url == null) {
      _snack('Enter a valid server URL, e.g. http://192.168.1.10:5050');
      return;
    }
    final env = await _store.addSavedEnv(name, url);
    await _select(ServerPreset(label: env.name, apiBaseUrl: env.url));
    if (mounted) setState(() => _addingCustom = false);
  }

  Future<void> _saveEncrypted() async {
    try {
      final json = await DevDiagnostics.buildEncryptedBundle(
        entries: _buffer.entries,
        envLabel: _activeLabel(FlavorConfig.current),
        envUrl: _currentBaseUrl,
        keyHex: _store.encKey,
      );
      final file = File('${Directory.systemTemp.path}/balsm-${DateTime.now().millisecondsSinceEpoch}.enc.json');
      await file.writeAsString(json);
      await Clipboard.setData(ClipboardData(text: json));
      _snack('Encrypted bundle copied · ${file.path}');
    } on Object catch (e) {
      _snack('Encrypt failed: $e');
    }
  }

  Future<void> _sendToSentry() async {
    setState(() => _sendStatus = 'sending');
    try {
      final ok = await DevDiagnostics.sendToSentry(
        entries: _buffer.entries,
        envLabel: _activeLabel(FlavorConfig.current),
        envUrl: _currentBaseUrl,
      );
      if (mounted) setState(() => _sendStatus = ok ? 'sent' : 'error');
    } on Object catch (_) {
      if (mounted) setState(() => _sendStatus = 'error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    if (mounted) setState(() => _sendStatus = null);
  }

  Future<void> _sendBugReport() async {
    final size = MediaQuery.sizeOf(context);
    setState(() => _bugSendStatus = 'sending');
    try {
      final ok = await DevDiagnostics.sendBugReport(
        title: _bugTitleCtrl.text,
        steps: _bugStepsCtrl.text,
        severity: ref.read(bugReportDraftProvider).severity,
        entries: _buffer.entries,
        envLabel: _activeLabel(FlavorConfig.current),
        envUrl: _currentBaseUrl,
        viewport: '${size.width.round()}×${size.height.round()}',
        screenshot: ref.read(bugReportDraftProvider).attachShot ? widget.screenshot : null,
      );
      if (mounted) setState(() => _bugSendStatus = ok ? 'sent' : 'error');
    } on Object catch (_) {
      if (mounted) setState(() => _bugSendStatus = 'error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    if (mounted) setState(() => _bugSendStatus = null);
  }

  void _copyReport() {
    final size = MediaQuery.sizeOf(context);
    final report = DevDiagnostics.buildBugReport(
      title: _bugTitleCtrl.text,
      steps: _bugStepsCtrl.text,
      severity: ref.read(bugReportDraftProvider).severity,
      envLabel: _activeLabel(FlavorConfig.current),
      envUrl: _currentBaseUrl,
      entries: _buffer.entries,
      viewport: '${size.width.round()}×${size.height.round()}',
    );
    unawaited(Clipboard.setData(ClipboardData(text: report)));
    setState(() => _reportCopied = true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _reportCopied = false);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  String _hms(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}

/// Small custom switch matching the design's 42×24 pill toggle.
class _DcToggle extends StatelessWidget {
  const _DcToggle({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: _toggleAnimation,
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AppColors.hueBlue : AppColors.ink200,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _toggleAnimation,
              curve: Curves.easeOut,
              left: on ? 20 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: DevConsoleColors.shadow, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// Per-environment accent, keyed off the preset label — mirrors the Dev Config
/// design's `DC_ENVS` palette (Local green · Dev blue · Staging amber · Prod red).
class _EnvStyle {
  const _EnvStyle(this.dot, this.bg, this.fg, {this.isProd = false});

  factory _EnvStyle.of(String label) {
    final l = label.toLowerCase();
    if (l.contains('local')) {
      return const _EnvStyle(AppColors.hueMint600, AppColors.hueMint50, AppColors.onSuccessBackground);
    }
    if (l.contains('prod')) {
      return const _EnvStyle(AppColors.danger, AppColors.dangerBackground, AppColors.onDangerBackground, isProd: true);
    }
    if (l.contains('stag')) {
      return const _EnvStyle(AppColors.warning, AppColors.warningBackground, AppColors.onWarningBackground);
    }
    if (l.contains('dev')) {
      return const _EnvStyle(AppColors.hueBlue, AppColors.hueBlue50, AppColors.onInfoBackground);
    }
    return const _EnvStyle(AppColors.ink600, AppColors.cream100, DevConsoleColors.panel);
  }

  final Color dot;
  final Color bg;
  final Color fg;
  final bool isProd;
}

class _EnvChip extends StatelessWidget {
  const _EnvChip(this.label, this.es);
  final String label;
  final _EnvStyle es;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: es.bg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: es.dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: FontSizes.micro,
                fontWeight: FontWeight.w700,
                color: es.fg,
              ),
            ),
          ],
        ),
      );
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.ink100)),
          ),
          child: const Text(
            'SAVED',
            style: TextStyle(
              fontSize: FontSizes.micro,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textHint,
            ),
          ),
        ),
      );
}

class _TinyBtn extends StatelessWidget {
  const _TinyBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.ink100,
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _kMono,
              fontSize: FontSizes.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.ink600,
            ),
          ),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.dangerBackground,
          borderRadius: BorderRadius.circular(_badgeRadius),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            fontSize: _badgeFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.danger,
          ),
        ),
      );
}

class _MonoField extends StatelessWidget {
  const _MonoField(this.label, this.ctrl, {this.hint});
  final String label;
  final TextEditingController ctrl;
  final String? hint;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: const TextStyle(fontFamily: _kMono, fontSize: FontSizes.micro, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontFamily: _kMono, fontSize: FontSizes.meta),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ],
      );
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Read-only in production. Server switching is disabled.',
                style: TextStyle(fontSize: FontSizes.eyebrow, height: 1.5, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
}

class _TermRow extends StatelessWidget {
  const _TermRow(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(
                k,
                style: const TextStyle(fontFamily: _kMono, fontSize: _monoFontSize, color: DevConsoleColors.textMuted),
              ),
            ),
            Expanded(
              child: SelectableText(
                v,
                style: const TextStyle(fontFamily: _kMono, fontSize: _monoFontSize, color: DevConsoleColors.text),
              ),
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.val, this.dot);
  final String label;
  final int val;
  final Color dot;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: FontSizes.eyebrow,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$val',
                style: const TextStyle(
                  fontFamily: _kMono,
                  fontWeight: FontWeight.w700,
                  fontSize: FontSizes.headline,
                  height: 1,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: DevConsoleColors.chipFill, borderRadius: BorderRadius.circular(_chipRadius)),
          child: Text(
            label,
            style: const TextStyle(fontFamily: _kMono, fontSize: FontSizes.micro, color: DevConsoleColors.textDim),
          ),
        ),
      );
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.child, required this.onTap, this.border});
  final Widget child;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: border ?? AppColors.border),
          ),
          child: child,
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(_iconTileRadius),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: AppColors.textTertiary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log content is never shown here. Save encrypted or send to Sentry to inspect.',
                style: TextStyle(fontSize: FontSizes.eyebrow, height: 1.5, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: FontSizes.eyebrow,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
      );
}

// ── Connection check ────────────────────────────────────────────────────────
// Ports the design's Backend health row: a dark action button on the left and
// a live one-line status on the right. Checks the SELECTED base URL, which is
// usually not the one the app is currently pointed at — that is the whole
// point of checking before switching.
class _HealthRow extends ConsumerWidget {
  const _HealthRow({required this.baseUrl});

  /// Where requests go now — what the check probes.
  final String baseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(serverHealthProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HealthButton(
                checking: health.status == ServerHealthStatus.checking,
                onCheck: () => ref.read(serverHealthProvider.notifier).check(baseUrl),
              ),
              const SizedBox(width: 8),
              Expanded(child: _HealthStatusLine(health: health, baseUrl: baseUrl)),
            ],
          ),
          if (health.details.isNotEmpty) _HealthDetails(health.details),
        ],
      ),
    );
  }
}

class _HealthButton extends StatelessWidget {
  const _HealthButton({required this.checking, required this.onCheck});
  final bool checking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: checking ? null : onCheck,
        child: Opacity(
          opacity: checking ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink800,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checking)
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.cream100),
                  )
                else
                  const Icon(Icons.monitor_heart_outlined, size: 13, color: AppColors.cream100),
                const SizedBox(width: 6),
                Text(
                  checking ? 'Checking…' : 'Check connection',
                  style: const TextStyle(
                    fontFamily: _kMono,
                    fontSize: FontSizes.eyebrow,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream100,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HealthStatusLine extends StatelessWidget {
  const _HealthStatusLine({required this.health, required this.baseUrl});
  final ServerHealthState health;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow);

    // While checking, the design shows the URL under test rather than a
    // placeholder — it is the one moment the developer wants it confirmed.
    final (Color color, IconData? icon, String text) = switch (health.status) {
      ServerHealthStatus.idle => (AppColors.textHint, null, 'Not checked yet'),
      ServerHealthStatus.checking => (AppColors.textHint, null, baseUrl),
      ServerHealthStatus.ok => (AppColors.hueMintInk, Icons.check_circle_outline, health.message),
      ServerHealthStatus.fail => (AppColors.danger, Icons.cancel_outlined, health.message),
    };

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono.copyWith(color: color)),
        ),
      ],
    );
  }
}

// Every field the server put in its health body, in the order it sent them —
// the deployed version, readiness and the reason when it is not ready. Values
// are selectable so a version or timestamp can be pasted into a bug report.
class _HealthDetails extends StatelessWidget {
  const _HealthDetails(this.details);
  final Map<String, Object?> details;

  @override
  Widget build(BuildContext context) {
    const key = TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow, color: AppColors.textHint);
    const value = TextStyle(fontFamily: _kMono, fontSize: FontSizes.eyebrow, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...details.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text(e.key, style: key)),
                  Expanded(child: SelectableText(e.value == null ? '—' : '${e.value}', style: value)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One severity choice on the Report bug tab.
class _SeverityButton extends ConsumerWidget {
  const _SeverityButton({required this.id, required this.label});
  final String id;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(bugReportDraftProvider.select((d) => d.severity == id));
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: GestureDetector(
        onTap: () => ref.read(bugReportDraftProvider.notifier).setSeverity(id),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.textPrimary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: on ? AppColors.textPrimary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: FontSizes.meta,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.white : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
