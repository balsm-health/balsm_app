import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';
import '../providers/disclosure_providers.dart';

/// Screen that presents the consolidated privacy disclosure to the patient.
///
/// Requirements:
/// - Scroll-based; CTA is pinned at the bottom and becomes enabled only
///   after the user has scrolled to the end of the content.
/// - Shows the supervisory authority for the patient's country.
/// - Fully localized via the module's i18n bundle.
/// - RTL-aware: wraps content in [Directionality] based on [preferredLanguage].
class ConsolidatedDisclosureScreen extends ConsumerStatefulWidget {
  const ConsolidatedDisclosureScreen({
    required this.disclosureId,
    required this.version,
    required this.countryCode,
    required this.preferredLanguage,
    super.key,
  });

  final String disclosureId;
  final String version;
  final String countryCode;
  final String preferredLanguage;

  @override
  ConsumerState<ConsolidatedDisclosureScreen> createState() => _ConsolidatedDisclosureScreenState();
}

class _ConsolidatedDisclosureScreenState extends ConsumerState<ConsolidatedDisclosureScreen> {
  final _scrollController = ScrollController();
  bool _scrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge && _scrollController.position.pixels > 0 && !_scrolledToEnd) {
      setState(() => _scrolledToEnd = true);
    }
  }

  bool get _isRtl {
    final lang = widget.preferredLanguage.toLowerCase();
    return lang.startsWith('ar') || lang.startsWith('he') || lang.startsWith('fa');
  }

  Future<void> _accept() async {
    final accepted = await ref.read(acceptDisclosureProvider.notifier).accept(
          disclosureId: widget.disclosureId,
          version: widget.version,
          countryCode: widget.countryCode,
          preferredLanguage: widget.preferredLanguage,
        );
    if (!accepted || !mounted) return;
    // Navigate to home on success — router handles the redirect.
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Typed, module-owned strings — compile-time checked; Messages_ar extends
    // Messages, so untranslated Arabic keys fall back to English.
    final m = disclosureMessagesOf(widget.preferredLanguage);

    final registry = ref.watch(countryRegistryProvider);
    final supervisoryAuthority = registry.supervisoryAuthority(widget.countryCode);
    final (:busy, :failure) = ref.watch(acceptDisclosureProvider.select((a) => (busy: a.busy, failure: a.failure)));

    return Directionality(
      textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.cream50,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Scrollable content ───────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _SectionCard(
                      icon: Icons.storage_outlined,
                      title: m.section.dataCollected.title,
                      body: m.section.dataCollected.body,
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.lock_outline,
                      title: m.section.howProtected.title,
                      body: m.section.howProtected.body,
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.gavel_outlined,
                      title: m.section.yourRights.title,
                      body: m.section.yourRights.body,
                    ),
                    const SizedBox(height: 12),
                    // Supervisory authority card
                    _SectionCard(
                      icon: Icons.account_balance_outlined,
                      title: m.section.supervisory.title,
                      body: m.section.supervisory.body(supervisoryAuthority),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.share_outlined,
                      title: m.section.sharing.title,
                      body: m.section.sharing.body,
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.delete_outline,
                      title: m.section.deletion.title,
                      body: m.section.deletion.body,
                    ),
                    const SizedBox(height: 24),
                    if (!_scrolledToEnd)
                      Center(
                        child: Text(
                          m.scrollToContinue,
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: FontSizes.bodySm,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // ── Error banner ─────────────────────────────────────────────
              if (failure case final failure?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BalsmErrorBanner(
                    message: failure.message,
                    onRetry: _accept,
                  ),
                ),
              // ── Fixed CTA ─────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.cream50,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
                child: BalsmButton(
                  label: m.accept,
                  onPressed: _scrolledToEnd && !busy ? _accept : null,
                  loading: busy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.hueBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: FontSizes.bodyLg,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: FontSizes.description,
                    color: AppColors.ink600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
