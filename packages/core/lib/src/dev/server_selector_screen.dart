import 'package:flutter/material.dart';
import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../network/balsm_api_controller.dart';

class ServerSelectorScreen extends StatefulWidget {
  const ServerSelectorScreen({super.key, required this.controller});
  final BalsmApiController controller;

  @override
  State<ServerSelectorScreen> createState() => _ServerSelectorScreenState();
}

class _ServerSelectorScreenState extends State<ServerSelectorScreen> {
  final _urlCtrl = TextEditingController();
  bool _loading = false;

  String get _currentBaseUrl => widget.controller.client.baseUrl;

  @override
  Widget build(BuildContext context) {
    // Reachable in every flavor (shake gesture). Server SWITCHING is only
    // allowed in dev/staging; in prod this is read-only diagnostics.
    final canSwitch = FlavorConfig.current.serverSwitchingEnabled;
    final cfg = FlavorConfig.current;
    return Scaffold(
      appBar: AppBar(title: const Text('Dev config')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DiagnosticsCard(
            appName: cfg.appName,
            flavor: cfg.flavor.name,
            brand: cfg.brand.name,
            baseUrl: _currentBaseUrl,
          ),
          const SizedBox(height: 16),
          if (canSwitch) ...[
            const _WarningBanner(),
            const SizedBox(height: 16),
            ...FlavorConfig.current.servers.map((p) => _PresetTile(
                  preset: p,
                  isActive: _currentBaseUrl == p.apiBaseUrl,
                  onTap: () => _select(p),
                )),
            const Divider(height: 32),
            _CustomForm(urlCtrl: _urlCtrl),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _applyCustom,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply custom'),
            ),
          ] else
            const _ReadOnlyNote(),
        ],
      ),
    );
  }

  Future<void> _select(ServerPreset preset) async {
    setState(() => _loading = true);
    try {
      await widget.controller.reconfigure(preset);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyCustom() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await _select(ServerPreset(label: 'Custom', apiBaseUrl: url));
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Changing server signs you out. Dev builds only.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });
  final ServerPreset preset;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(preset.label),
        subtitle: Text(preset.apiBaseUrl, style: const TextStyle(fontSize: 12)),
        trailing: isActive ? const Icon(Icons.check_circle, color: Colors.green) : null,
        onTap: onTap,
      );
}

class _CustomForm extends StatelessWidget {
  const _CustomForm({required this.urlCtrl});
  final TextEditingController urlCtrl;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Custom API URL', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              hintText: 'http://localhost:5000',
            ),
          ),
        ],
      );
}

/// Always-visible diagnostics: build/flavor + the live API endpoint.
class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.appName,
    required this.flavor,
    required this.brand,
    required this.baseUrl,
  });
  final String appName;
  final String flavor;
  final String brand;
  final String baseUrl;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('App', appName),
            _row('Brand', brand),
            _row('Flavor', flavor),
            _row('API server', baseUrl),
          ],
        ),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            ),
            Expanded(
              child: SelectableText(v, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}

/// Shown instead of the switcher when server switching is disabled (prod).
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.blueGrey, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Read-only in production. Server switching is disabled.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
