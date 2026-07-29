import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Identity channel offered during public re-authentication.
enum ReauthChannel { email, phone, handle }

extension ReauthChannelLabel on ReauthChannel {
  String get label => switch (this) {
        ReauthChannel.email => 'Email',
        ReauthChannel.phone => 'Phone',
        ReauthChannel.handle => 'Handle',
      };

  TextInputType get keyboardType => switch (this) {
        ReauthChannel.email => TextInputType.emailAddress,
        ReauthChannel.phone => TextInputType.phone,
        ReauthChannel.handle => TextInputType.text,
      };
}

/// Result of a completed re-authentication form submission.
class ReauthCredentials {
  const ReauthCredentials({
    required this.channel,
    required this.identifier,
    required this.secret,
  });

  final ReauthChannel channel;
  final String identifier;
  final String secret;
}

/// Self-contained 3-channel re-auth form used by the public (no-session)
/// deletion + cancellation routes.
///
/// Works identically on web and mobile (no platform-specific deps). When the
/// `auth` package exposes a shared re-auth use case, the [onSubmit] callback is
/// the seam to delegate to it before invoking the deletion endpoints.
class ReauthForm extends StatefulWidget {
  const ReauthForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.submitVariant = BalsmButtonVariant.primary,
    this.submitting = false,
    this.error,
  });

  final ValueChanged<ReauthCredentials> onSubmit;
  final String submitLabel;
  final BalsmButtonVariant submitVariant;
  final bool submitting;
  final String? error;

  @override
  State<ReauthForm> createState() => _ReauthFormState();
}

class _ReauthFormState extends State<ReauthForm> {
  ReauthChannel _channel = ReauthChannel.email;
  final _identifier = TextEditingController();
  final _secret = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _valid => _identifier.text.trim().isNotEmpty && _secret.text.isNotEmpty;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verify it is you',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BalsmColors.fg1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in again to continue.',
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
        BalsmTextField(
          label: 'Password',
          controller: _secret,
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
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
