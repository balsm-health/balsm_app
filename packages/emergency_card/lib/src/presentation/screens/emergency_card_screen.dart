import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/emergency_snapshot_reader.dart';
import '../../application/use_cases/mint_emergency_qr_token_use_case.dart';
import '../../domain/aggregates/emergency_card_snapshot.dart';
import 'qr_code_display_screen.dart';

/// TTL choices offered when generating a QR.
const _ttlOptions = <({String label, int seconds})>[
  (label: '1 hour', seconds: 3600),
  (label: '4 hours', seconds: 14400),
  (label: '24 hours', seconds: 86400),
  (label: '7 days', seconds: 604800),
];

/// The patient-facing emergency card: shows blood type, allergies, conditions
/// and the primary contact, with a "Generate QR" action.
class EmergencyCardScreen extends ConsumerStatefulWidget {
  const EmergencyCardScreen({super.key});

  @override
  ConsumerState<EmergencyCardScreen> createState() =>
      _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends ConsumerState<EmergencyCardScreen> {
  EmergencyCardSnapshot? _snapshot;
  bool _loading = true;
  bool _minting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot =
        await ref.read(emergencySnapshotReaderProvider).readSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _onGenerate() async {
    final ttl = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'QR valid for',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final opt in _ttlOptions)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(opt.label),
                onTap: () => Navigator.pop(ctx, opt.seconds),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (ttl == null) return;
    await _mint(ttl);
  }

  Future<void> _mint(int ttlSeconds) async {
    setState(() => _minting = true);
    final result = await ref
        .read(mintEmergencyQrTokenUseCaseProvider)
        .call(ttlSeconds: ttlSeconds);
    if (!mounted) return;
    setState(() => _minting = false);
    result.fold(
      (mint) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              QrCodeDisplayScreen(token: mint.token, qrUrl: mint.qrUrl),
        ),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Card')),
      body: SafeArea(
        child: _loading
            ? const BalsmLoadingIndicator()
            : (snapshot == null || !snapshot.hasAnyData)
                ? _EmptyNudge()
                : _CardBody(snapshot: snapshot),
      ),
      bottomNavigationBar: (_loading || snapshot == null || !snapshot.hasAnyData)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BalsmButton(
                  label: 'Generate QR',
                  icon: Icons.qr_code_2,
                  loading: _minting,
                  onPressed: _onGenerate,
                ),
              ),
            ),
    );
  }
}

class _EmptyNudge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_information_outlined,
                size: 56, color: BalsmColors.ink400),
            const SizedBox(height: 16),
            const Text(
              'Add your health details first',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set your blood type, allergies, conditions and an emergency '
              'contact in your profile so they can be shared in an emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BalsmColors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.snapshot});

  final EmergencyCardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final contact = snapshot.primaryContact;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (snapshot.bloodType != null) ...[
          _SectionLabel('Blood type'),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: BalsmColors.dangerBg,
                borderRadius: BorderRadius.circular(BalsmRadius.md),
              ),
              child: Text(
                snapshot.bloodType!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BalsmColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (snapshot.allergyNames.isNotEmpty) ...[
          _SectionLabel('Allergies'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in snapshot.allergyNames)
                BalsmPill(label: a, variant: BalsmPillVariant.danger),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (snapshot.conditionNames.isNotEmpty) ...[
          _SectionLabel('Conditions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in snapshot.conditionNames)
                BalsmPill(label: c, variant: BalsmPillVariant.info),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (contact != null) ...[
          _SectionLabel('Emergency contact'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.contact_phone_outlined),
            title: Text(contact.name),
            subtitle: Text(contact.phone),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: BalsmColors.fg3,
          letterSpacing: 0.4,
        ),
      );
}
