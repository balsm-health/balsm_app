import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/ports/reauth_port.dart';
import '../i18n/i18n.dart';
import '../providers/deletion_flow.dart';

// ReauthChannel / ReauthCredentials live in the application layer, beside the
// port that consumes them — a port must not import presentation.
export '../../application/ports/reauth_port.dart' show ReauthChannel, ReauthCredentials;

/// Self-contained 3-channel re-auth form used by the public (no-session)
/// deletion + cancellation routes.
///
/// Works identically on web and mobile (no platform-specific deps). The chosen
/// channel, the in-flight flag and the last failure live in the
/// [deletionFlowProvider] for [entry]; the identifier and the code stay in this
/// form's text fields and pass straight through to the port. Neither is logged.
class ReauthForm extends ConsumerStatefulWidget {
  const ReauthForm({
    required this.entry,
    required this.submitLabel,
    super.key,
    this.submitVariant = BalsmButtonVariant.primary,
  });

  final DeletionEntry entry;
  final String submitLabel;
  final BalsmButtonVariant submitVariant;

  @override
  ConsumerState<ReauthForm> createState() => _ReauthFormState();
}

class _ReauthFormState extends ConsumerState<ReauthForm> {
  final _identifier = TextEditingController();
  final _secret = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool _codeSent = false;

  bool get _hasIdentifier => _identifier.text.trim().isNotEmpty;
  bool get _valid => _hasIdentifier && _secret.text.isNotEmpty;

  DeletionFlowNotifier get _flow => ref.read(deletionFlowProvider(widget.entry).notifier);

  void _requestCode() {
    if (!_hasIdentifier) return;
    setState(() => _codeSent = true);
    unawaited(_flow.sendCode(_identifier.text.trim()));
  }

  void _submit(ReauthChannel channel) {
    if (!_valid) return;
    unawaited(
      _flow.verify(
        ReauthCredentials(
          channel: channel,
          identifier: _identifier.text.trim(),
          secret: _secret.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(deletionStringsProvider);
    final (:channel, :submitting, :failure) = ref.watch(
      deletionFlowProvider(widget.entry).select((f) => (channel: f.channel, submitting: f.submitting, failure: f.failure)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m.verifyHeading,
          style: const TextStyle(
            fontSize: FontSizes.subhead,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          m.verifyBody,
          style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ...ReauthChannel.values.map(
              (c) => ChoiceChip(
                label: Text(c.label),
                selected: channel == c,
                onSelected: (_) => _flow.selectChannel(c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BalsmTextField(
          label: channel.label,
          controller: _identifier,
          keyboardType: channel.keyboardType,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        BalsmButton(
          label: _codeSent ? m.sendCodeAgain : m.sendCode,
          variant: BalsmButtonVariant.secondary,
          onPressed: _hasIdentifier && !submitting ? _requestCode : null,
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          BalsmTextField(
            label: m.otpLabel,
            controller: _secret,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (failure case final failure?) ...[
          const SizedBox(height: 16),
          BalsmErrorBanner(message: failure.message),
        ],
        const SizedBox(height: 20),
        BalsmButton(
          label: widget.submitLabel,
          variant: widget.submitVariant,
          loading: submitting,
          onPressed: (_valid && !submitting) ? () => _submit(channel) : null,
        ),
      ],
    );
  }
}
