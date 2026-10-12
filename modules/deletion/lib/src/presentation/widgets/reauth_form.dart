import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

import '../../application/ports/reauth_port.dart';

// ReauthChannel / ReauthCredentials live in the application layer, beside the
// port that consumes them — a port must not import presentation.
export '../../application/ports/reauth_port.dart' show ReauthChannel, ReauthCredentials;

/// Self-contained 3-channel re-auth form used by the public (no-session)
/// deletion + cancellation routes.
///
/// Works identically on web and mobile (no platform-specific deps).
/// [onRequestChallenge] sends the one-time code; [onSubmit] carries the code
/// back for verification. Neither the identifier nor the code is logged.
class ReauthForm extends ConsumerStatefulWidget {
  const ReauthForm({
    super.key,
    required this.onSubmit,
    required this.onRequestChallenge,
    required this.submitLabel,
    this.submitVariant = BalsmButtonVariant.primary,
    this.submitting = false,
    this.error,
  });

  final ValueChanged<ReauthCredentials> onSubmit;

  /// Sends the one-time code to the identifier the person typed.
  final void Function(ReauthChannel channel, String identifier) onRequestChallenge;

  final String submitLabel;
  final BalsmButtonVariant submitVariant;
  final bool submitting;
  final String? error;

  @override
  ConsumerState<ReauthForm> createState() => _ReauthFormState();
}

class _ReauthFormState extends ConsumerState<ReauthForm> {
  ReauthChannel _channel = ReauthChannel.email;
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

  void _requestCode() {
    if (!_hasIdentifier) return;
    setState(() => _codeSent = true);
    widget.onRequestChallenge(_channel, _identifier.text.trim());
  }

  void _submit() {
    if (!_valid) return;
    widget.onSubmit(ReauthCredentials(
      channel: _channel,
      identifier: _identifier.text.trim(),
      secret: _secret.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(deletionStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m.verifyHeading,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BalsmColors.fg1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          m.verifyBody,
          style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ...ReauthChannel.values.map(
              (channel) => ChoiceChip(
                label: Text(channel.label),
                selected: _channel == channel,
                onSelected: (_) => setState(() => _channel = channel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BalsmTextField(
          label: _channel.label,
          controller: _identifier,
          keyboardType: _channel.keyboardType,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        BalsmButton(
          label: _codeSent ? m.sendCodeAgain : m.sendCode,
          variant: BalsmButtonVariant.secondary,
          onPressed: _hasIdentifier && !widget.submitting ? _requestCode : null,
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
        if (widget.error != null) ...[
          const SizedBox(height: 16),
          BalsmErrorBanner(message: widget.error!),
        ],
        const SizedBox(height: 20),
        BalsmButton(
          label: widget.submitLabel,
          variant: widget.submitVariant,
          loading: widget.submitting,
          onPressed: (_valid && !widget.submitting) ? _submit : null,
        ),
      ],
    );
  }
}
