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

  @override
  void initState() {
    super.initState();
    if (!FlavorConfig.current.serverSelectorEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    }
  }

  String get _currentBaseUrl => widget.controller.client.baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Switch server')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
