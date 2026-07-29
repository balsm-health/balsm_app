import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Step 1 of auth flow: user selects their country.
///
/// On selection, the callback [onCountrySelected] is invoked with the ISO
/// 3166-1 alpha-2 code so the router can navigate to email or social sign-in.
class CountryPickerScreen extends ConsumerStatefulWidget {
  const CountryPickerScreen({
    super.key,
    required this.onCountrySelected,
    this.totalSteps = 3,
    this.currentStep = 1,
  });

  /// Called when the user taps a country row.
  final ValueChanged<String> onCountrySelected;

  final int totalSteps;
  final int currentStep;

  @override
  ConsumerState<CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends ConsumerState<CountryPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _countries = [
    (code: 'EG', name: 'Egypt'),
    (code: 'SA', name: 'Saudi Arabia'),
    (code: 'AE', name: 'United Arab Emirates'),
    (code: 'JO', name: 'Jordan'),
    (code: 'KW', name: 'Kuwait'),
    (code: 'QA', name: 'Qatar'),
    (code: 'BH', name: 'Bahrain'),
    (code: 'OM', name: 'Oman'),
    (code: 'LB', name: 'Lebanon'),
    (code: 'GB', name: 'United Kingdom'),
    (code: 'US', name: 'United States'),
    (code: 'DE', name: 'Germany'),
    (code: 'FR', name: 'France'),
    (code: 'CA', name: 'Canada'),
    (code: 'AU', name: 'Australia'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({String code, String name})> get _filtered => _query.isEmpty
      ? _countries
      : _countries.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  BalsmRoundButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onTap: () => Navigator.of(context).maybePop(),
                    semanticLabel: 'Back',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BalsmStepDots(
                    totalSteps: widget.totalSteps,
                    currentStep: widget.currentStep,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select your country',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We use this to apply the right data protection rules for you.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: isDark ? cs.surface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BalsmRadius.lg),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Country list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                itemBuilder: (_, i) {
                  final country = _filtered[i];
                  return ListTile(
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.35), size: 20),
                    onTap: () => widget.onCountrySelected(country.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
