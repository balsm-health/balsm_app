import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../kit/_tokens.dart';
import '../network/balsm_api_controller.dart';
import 'dev_config_store.dart';
import 'dev_diagnostics.dart';
import 'dev_log_buffer.dart';

// Dark "terminal" chrome from the Dev Config design (claude.ai/design · Balsm App).
const _kTermBg = Color(0xFF1A1A17);
const _kTermAccent = Color(0xFFA3FF6E); // lime — the console accent
const _kMono = 'monospace';

/// Dev Config — full port of the design's three-tab overlay
/// (Environment · Logs · Report bug). Reachable in EVERY flavor (shake gesture);
/// server SWITCHING and log EXPORT are dev/staging only. In prod this renders
/// read-only diagnostics with the switcher hidden (a mis-pointed prod build
/// could leak PHI to the wrong backend).
class ServerSelectorScreen extends StatefulWidget {
  const ServerSelectorScreen({super.key, required this.controller});
  final BalsmApiController controller;

  @override
  State<ServerSelectorScreen> createState() => _ServerSelectorScreenState();
}

class _ServerSelectorScreenState extends State<ServerSelectorScreen> {
  final _store = DevConfigStore();
  final _buffer = DevLogBuffer.instance;

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
  String _bugSeverity = 'medium';
  bool _reportCopied = false;

  String get _currentBaseUrl => widget.controller.client.baseUrl;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _buffer.addListener(_onChange);
    _store.load();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    _buffer.removeListener(_onChange);
    _store.dispose();
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
      if (p.apiBaseUrl == _currentBaseUrl) return p.label;
    }
    for (final e in _store.savedEnvs) {
      if (e.url == _currentBaseUrl) return e.name;
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = FlavorConfig.current;
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          children: [
            _header(cfg),
            _tabStrip(),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: BalsmColors.appAccent,
                backgroundColor: BalsmColors.ink100,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                children: switch (_tab) {
                  'logs' => _logsBody(cfg),
                  'bug' => _bugBody(),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: const BoxDecoration(color: BalsmColors.surface),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kTermBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.terminal, size: 20, color: _kTermAccent),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BalsmColors.fg1,
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
                          fontSize: 10,
                          color: BalsmColors.fg4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _envChip(label, es),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, size: 20, color: BalsmColors.fg3),
          ),
        ],
      ),
    );
  }

  Widget _envChip(String label, _EnvStyle es) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: es.bg,
          borderRadius: BorderRadius.circular(BalsmRadius.pill),
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
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: es.fg,
              ),
            ),
          ],
        ),
      );

  // ── Tab strip ───────────────────────────────────────────────────────────────
  Widget _tabStrip() {
    final err = _buffer.errorCount;
    final tabs = <List<Object>>[
      ['env', Icons.dns_outlined, 'Environment'],
      ['logs', Icons.subject, err > 0 ? 'Logs · $err err' : 'Logs'],
      ['bug', Icons.bug_report_outlined, 'Report bug'],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: BalsmColors.surface,
        border: Border(
          top: BorderSide(color: BalsmColors.ink100),
          bottom: BorderSide(color: BalsmColors.ink100),
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
                      color: on ? BalsmColors.appAccent : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t[1] as IconData,
                        size: 14,
                        color: on ? BalsmColors.appAccent : BalsmColors.fg3),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        t[2] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: on ? BalsmColors.appAccent : BalsmColors.fg3,
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
        _eyebrow('Backend'),
        ...cfg.servers.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _presetCard(p,
                  active: _currentBaseUrl == p.apiBaseUrl,
                  onTap: () => _onPresetTap(p)),
            )),
        if (_store.savedEnvs.isNotEmpty) ...[
          _savedHeader(),
          ..._store.savedEnvs.map(_savedEnvTile),
        ],
        if (_addingCustom) _customForm() else _addCustomButton(),
        if (_pendingProd != null) _prodConfirm(_pendingProd!),
        _featureFlags(),
        _buildCard(cfg),
      ];

  List<Widget> _readOnlyBody(FlavorConfig cfg) {
    final active = cfg.servers.firstWhere(
      (p) => p.apiBaseUrl == _currentBaseUrl,
      orElse: () =>
          ServerPreset(label: _activeLabel(cfg), apiBaseUrl: _currentBaseUrl),
    );
    return [
      _eyebrow('Backend'),
      _presetCard(active, active: true, onTap: null),
      const SizedBox(height: 12),
      _readOnlyNote(),
      _buildCard(cfg),
    ];
  }

  Widget _savedHeader() => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: BalsmColors.ink100)),
          ),
          child: const Text(
            'SAVED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: BalsmColors.fg4,
            ),
          ),
        ),
      );

  Widget _savedEnvTile(SavedEnv se) {
    final active = _currentBaseUrl == se.url;
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
                color: active ? BalsmColors.ink50 : BalsmColors.surface,
                borderRadius: BorderRadius.circular(BalsmRadius.lg),
                border: Border.all(
                  color: active ? const Color(0xFF6B6B60) : BalsmColors.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Color(0xFF6B6B60), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(se.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF3A3A34)
                                    : BalsmColors.fg1)),
                        const SizedBox(height: 1),
                        Text(se.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: _kMono,
                                fontSize: 11,
                                color: Color(0xFF6B6B60))),
                      ],
                    ),
                  ),
                  if (active)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF6B6B60)),
                    ),
                  _tinyBtn('edit', () {
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
                    icon: const Icon(Icons.close, size: 14, color: BalsmColors.fg4),
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

  Widget _tinyBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: BalsmColors.ink100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontFamily: _kMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B60))),
        ),
      );

  Widget _editForm(SavedEnv se) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BalsmColors.ink50,
          borderRadius: BorderRadius.circular(BalsmRadius.lg),
          border: Border.all(color: const Color(0xFF6B6B60), width: 1.5),
        ),
        child: Column(
          children: [
            _monoField('name', _editNameCtrl),
            const SizedBox(height: 8),
            _monoField('url', _editUrlCtrl),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _editingId = null),
                  child: const Text('Cancel',
                      style: TextStyle(color: BalsmColors.fg3)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final n = _editNameCtrl.text.trim();
                    final u = _editUrlCtrl.text.trim();
                    if (n.isEmpty || u.isEmpty) return;
                    _store.updateSavedEnv(se.id, n, u);
                    setState(() => _editingId = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A34),
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
  Widget _presetCard(ServerPreset p,
      {required bool active, VoidCallback? onTap}) {
    final es = _EnvStyle.of(p.label);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: active ? es.bg : BalsmColors.surface,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(
          color: active ? es.dot : BalsmColors.border,
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
                    Text(p.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: active ? es.fg : BalsmColors.fg1)),
                    if (es.isProd) ...[
                      const SizedBox(width: 7),
                      _liveBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(p.apiBaseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: _kMono,
                        fontSize: 11,
                        color: active ? es.fg : BalsmColors.fg4)),
              ],
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle, size: 19, color: es.dot),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }

  Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: BalsmColors.dangerBg,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text('LIVE',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: BalsmColors.danger)),
      );

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
            borderRadius: BorderRadius.circular(BalsmRadius.lg),
            border: Border.all(color: BalsmColors.border, width: 1.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.add, size: 16, color: BalsmColors.fg3),
              SizedBox(width: 8),
              Text('Add custom environment',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BalsmColors.fg3)),
            ],
          ),
        ),
      );

  Widget _customForm() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BalsmColors.ink50,
          borderRadius: BorderRadius.circular(BalsmRadius.lg),
          border: Border.all(color: BalsmColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEW ENVIRONMENT',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: BalsmColors.fg3)),
            const SizedBox(height: 10),
            _monoField('name', _nameCtrl, hint: 'My Staging'),
            const SizedBox(height: 8),
            _monoField('url', _urlCtrl, hint: 'https://api.example.com'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _addingCustom = false),
                  child: const Text('Cancel',
                      style: TextStyle(color: BalsmColors.fg3)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _saveCustom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BalsmColors.appAccent,
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

  Widget _monoField(String label, TextEditingController ctrl, {String? hint}) =>
      Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: _kMono, fontSize: 10, color: BalsmColors.fg3)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontFamily: _kMono, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                filled: true,
                fillColor: BalsmColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: BalsmColors.border),
                ),
              ),
            ),
          ),
        ],
      );

  // ── Production-switch confirm ──────────────────────────────────────────────
  Widget _prodConfirm(ServerPreset p) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: BalsmColors.dangerBg,
          borderRadius: BorderRadius.circular(BalsmRadius.lg),
          border: Border.all(color: BalsmColors.danger, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: BalsmColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Switch to production?',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A2A20))),
                      SizedBox(height: 3),
                      Text(
                        'Real patient data. Real consequences. Any action here is permanent.',
                        style: TextStyle(
                            fontSize: 12, height: 1.5, color: Color(0xFF9B3A2F)),
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
                      foregroundColor: BalsmColors.fg2,
                      side: const BorderSide(color: BalsmColors.border),
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
                      _select(t);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: BalsmColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Switch anyway'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _readOnlyNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BalsmColors.ink50,
          borderRadius: BorderRadius.circular(BalsmRadius.md),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 14, color: BalsmColors.fg3),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Read-only in production. Server switching is disabled.',
                style:
                    TextStyle(fontSize: 11, height: 1.5, color: BalsmColors.fg3),
              ),
            ),
          ],
        ),
      );

  // ── Feature flags ───────────────────────────────────────────────────────────
  Widget _featureFlags() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _eyebrow('Feature flags'),
          Container(
            decoration: BoxDecoration(
              color: BalsmColors.surface,
              borderRadius: BorderRadius.circular(BalsmRadius.lg),
              border: Border.all(color: BalsmColors.border),
            ),
            child: Column(
              children: [
                ...kDevFlags.indexed
                    .map((e) => _flagRow(e.$2, first: e.$1 == 0)),
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
          color: on ? BalsmColors.appAccent50 : Colors.transparent,
          border: first
              ? null
              : const Border(top: BorderSide(color: BalsmColors.ink100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BalsmColors.fg1)),
                  const SizedBox(height: 1),
                  Text(f.desc,
                      style:
                          const TextStyle(fontSize: 11, color: BalsmColors.fg3)),
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
          color: _kTermBg,
          borderRadius: BorderRadius.circular(BalsmRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('// build',
                  style: TextStyle(
                      fontFamily: _kMono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kTermAccent)),
            ),
            _termRow('app', cfg.appName),
            _termRow('brand', cfg.brand.name),
            _termRow('flavor', cfg.flavor.name),
            _termRow('server', _currentBaseUrl),
          ],
        ),
      );

  Widget _termRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(k,
                  style: const TextStyle(
                      fontFamily: _kMono,
                      fontSize: 10.5,
                      color: Color(0xFF6E6E64))),
            ),
            Expanded(
              child: SelectableText(v,
                  style: const TextStyle(
                      fontFamily: _kMono,
                      fontSize: 10.5,
                      color: Color(0xFFC8C8BE))),
            ),
          ],
        ),
      );

  // ══ LOGS TAB ═════════════════════════════════════════════════════════════════
  List<Widget> _logsBody(FlavorConfig cfg) {
    final canExport = cfg.serverSwitchingEnabled; // dev/staging only
    final last = _buffer.lastAt;
    return [
      _eyebrow('Summary'),
      Row(
        children: [
          _statCard('Total', _buffer.total, const Color(0xFFC8C8BE)),
          const SizedBox(width: 8),
          _statCard('Errors', _buffer.errorCount, const Color(0xFFF87171)),
          const SizedBox(width: 8),
          _statCard('Warnings', _buffer.warnCount, const Color(0xFFFBBF24)),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Last entry: ${last == null ? '—' : _hms(last)}',
        style: const TextStyle(fontSize: 11, color: BalsmColors.fg3),
      ),
      const SizedBox(height: 16),
      _eyebrow('Encryption key'),
      _encKeyCard(),
      const SizedBox(height: 4),
      if (!canExport) _readOnlyNote() else ...[
        _eyebrow('Export'),
        _exportButton(
          icon: Icons.lock_outline,
          iconBg: BalsmColors.appAccent50,
          iconColor: BalsmColors.appAccent,
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
      _privacyNote(),
    ];
  }

  Widget _statCard(String label, int val, Color dot) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BalsmColors.surface,
            borderRadius: BorderRadius.circular(BalsmRadius.lg),
            border: Border.all(color: BalsmColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BalsmColors.fg3)),
                ],
              ),
              const SizedBox(height: 4),
              Text('$val',
                  style: const TextStyle(
                      fontFamily: _kMono,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      height: 1,
                      color: BalsmColors.fg1)),
            ],
          ),
        ),
      );

  Widget _encKeyCard() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration:
            BoxDecoration(color: _kTermBg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.vpn_key, size: 14, color: _kTermAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _store.encKey.isEmpty ? '…' : _store.encKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: _kMono, fontSize: 11, color: Color(0xFFC8C8BE)),
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _store.encKey));
                _snack('Key copied');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(5)),
                child: const Text('copy',
                    style: TextStyle(
                        fontFamily: _kMono, fontSize: 10, color: Color(0xFF888888))),
              ),
            ),
          ],
        ),
      );

  Widget _exportButton({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      _cardButton(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BalsmColors.fg1)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: BalsmColors.fg3)),
              ],
            ),
          ],
        ),
      );

  Widget _sentryButton(FlavorConfig cfg) {
    final s = _sendStatus;
    final (bg, ic, icColor, title) = switch (s) {
      'sent' => (
          BalsmColors.petalMint50,
          Icons.check,
          BalsmColors.petalMint,
          'Sent to Sentry!'
        ),
      'error' => (
          BalsmColors.dangerBg,
          Icons.warning_amber_rounded,
          BalsmColors.danger,
          'Failed to send'
        ),
      'sending' => (BalsmColors.ink50, Icons.sync, BalsmColors.fg2, 'Sending…'),
      _ => (BalsmColors.ink50, Icons.send, BalsmColors.fg2, 'Send to Sentry'),
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

  Widget _clearButton() => _cardButton(
        border: BalsmColors.danger,
        onTap: () {
          _buffer.clear();
          _snack('Logs cleared');
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 16, color: BalsmColors.danger),
            SizedBox(width: 8),
            Text('Clear all logs',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BalsmColors.danger)),
          ],
        ),
      );

  Widget _cardButton(
          {required Widget child, required VoidCallback onTap, Color? border}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: BalsmColors.surface,
            borderRadius: BorderRadius.circular(BalsmRadius.lg),
            border: Border.all(color: border ?? BalsmColors.border),
          ),
          child: child,
        ),
      );

  Widget _privacyNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BalsmColors.ink50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: BalsmColors.fg3),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log content is never shown here. Save encrypted or send to Sentry to inspect.',
                style:
                    TextStyle(fontSize: 11, height: 1.5, color: BalsmColors.fg3),
              ),
            ),
          ],
        ),
      );

  // ══ BUG REPORT TAB ═══════════════════════════════════════════════════════════
  List<Widget> _bugBody() => [
        _eyebrow('Screenshot'),
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: BalsmColors.ink50,
            borderRadius: BorderRadius.circular(BalsmRadius.lg),
            border: Border.all(color: BalsmColors.border),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 26, color: BalsmColors.fg4),
              SizedBox(height: 8),
              Text('No screenshot captured',
                  style: TextStyle(
                      fontFamily: _kMono, fontSize: 12, color: BalsmColors.fg4)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Title'),
        TextField(
          controller: _bugTitleCtrl,
          decoration: _inputDeco('Brief description of the bug'),
        ),
        const SizedBox(height: 12),
        _fieldLabel('Steps to reproduce'),
        TextField(
          controller: _bugStepsCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: _inputDeco('1. Go to…\n2. Tap…\n3. Expected: …\n4. Actual: …'),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Severity'),
        Row(
          children: [
            ...const [
              ['low', 'Low'],
              ['medium', 'Medium'],
              ['high', 'High'],
              ['critical', 'Critical'],
            ].map((s) => Expanded(child: _sevButton(s[0], s[1]))),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _copyReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: BalsmColors.appAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: Icon(_reportCopied ? Icons.check : Icons.copy, size: 17),
          label: Text(
              _reportCopied ? 'Copied to clipboard!' : 'Copy report to clipboard'),
        ),
      ];

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BalsmColors.fg2)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: BalsmColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BalsmRadius.md),
          borderSide: const BorderSide(color: BalsmColors.border),
        ),
      );

  Widget _sevButton(String id, String label) {
    final on = _bugSeverity == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _bugSeverity = id),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? BalsmColors.fg1 : BalsmColors.surface,
            borderRadius: BorderRadius.circular(BalsmRadius.sm),
            border: Border.all(
                color: on ? BalsmColors.fg1 : BalsmColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : BalsmColors.fg3)),
        ),
      ),
    );
  }

  Widget _eyebrow(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: BalsmColors.fg3)),
      );

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _onPresetTap(ServerPreset p) {
    if (_currentBaseUrl == p.apiBaseUrl) return;
    if (_EnvStyle.of(p.label).isProd) {
      setState(() => _pendingProd = p);
      return;
    }
    _select(p);
  }

  Future<void> _select(ServerPreset preset) async {
    setState(() => _loading = true);
    try {
      await widget.controller.reconfigure(preset);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCustom() async {
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;
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
      final file = File(
          '${Directory.systemTemp.path}/balsm-${DateTime.now().millisecondsSinceEpoch}.enc.json');
      await file.writeAsString(json);
      await Clipboard.setData(ClipboardData(text: json));
      _snack('Encrypted bundle copied · ${file.path}');
    } catch (e) {
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
    } catch (_) {
      if (mounted) setState(() => _sendStatus = 'error');
    }
    await Future.delayed(const Duration(milliseconds: 3200));
    if (mounted) setState(() => _sendStatus = null);
  }

  void _copyReport() {
    final size = MediaQuery.of(context).size;
    final report = DevDiagnostics.buildBugReport(
      title: _bugTitleCtrl.text,
      steps: _bugStepsCtrl.text,
      severity: _bugSeverity,
      envLabel: _activeLabel(FlavorConfig.current),
      envUrl: _currentBaseUrl,
      entries: _buffer.entries,
      viewport: '${size.width.round()}×${size.height.round()}',
    );
    Clipboard.setData(ClipboardData(text: report));
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
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: on ? BalsmColors.appAccent : BalsmColors.ink200,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: on ? 20 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
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
  final Color dot;
  final Color bg;
  final Color fg;
  final bool isProd;

  static _EnvStyle of(String label) {
    final l = label.toLowerCase();
    if (l.contains('local')) {
      return const _EnvStyle(
          Color(0xFF3FC366), Color(0xFFE8F9EE), Color(0xFF1A6033));
    }
    if (l.contains('prod')) {
      return const _EnvStyle(
          Color(0xFFD44A3C), Color(0xFFFBEBE7), Color(0xFF7A2A20),
          isProd: true);
    }
    if (l.contains('stag')) {
      return const _EnvStyle(
          Color(0xFFE5B428), Color(0xFFFDF5DC), Color(0xFF7A5A0F));
    }
    if (l.contains('dev')) {
      return const _EnvStyle(
          Color(0xFF1283FF), Color(0xFFE4F0FF), Color(0xFF08407A));
    }
    return const _EnvStyle(
        Color(0xFF6B6B60), Color(0xFFF4F3EC), Color(0xFF3A3A34));
  }
}
