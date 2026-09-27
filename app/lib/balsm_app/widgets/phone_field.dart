import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Default national-number example (`PhoneInput`'s `placeholder` prop). Digits,
/// so it reads the same in both languages.
const String kPhoneHintExample = '10 1234 5678';

/// Arabic-Indic and Eastern Arabic-Indic digits folded to ASCII (FR-213).
///
/// Local rather than the profile module's copy: a phone field is a digit field,
/// and a generic widget should not pull a feature module in to type one.
String foldPhoneDigits(String input) {
  final out = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + (r - 0x0660)); // ٠-٩
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + (r - 0x06F0)); // ۰-۹
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// The flag for an ISO 3166-1 alpha-2 code, as regional indicator symbols.
String countryFlagEmoji(String code) {
  if (code.length != 2) return '\u{1F3F3}\u{FE0F}';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

/// Dial codes longest-first, so `+1` never shadows `+1…` and `+97` never
/// shadows `+971` when a stored number is parsed back apart.
final List<CountryCode> _byDialLength = () {
  final list = CountryCode.all.where((c) => c.dialCode.isNotEmpty).toList();
  list.sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  return list;
}();

/// One stored phone string split into its country and its national part.
///
/// A value that does not start with a known dial code keeps [fallback] and is
/// treated as national digits — numbers saved before this field existed, or
/// pasted local-format, must still show what the patient typed rather than
/// being silently reinterpreted.
({CountryCode country, String national}) splitPhone(String? value, {CountryCode? fallback}) {
  final v = (value ?? '').trim();
  final home = fallback ?? kHomeCountry;
  if (!v.startsWith('+')) return (country: home, national: v);
  for (final c in _byDialLength) {
    if (v.startsWith(c.dialCode)) {
      return (country: c, national: v.substring(c.dialCode.length).trim());
    }
  }
  return (country: home, national: v);
}

/// The stored form: `+20 10 1234 5678`.
///
/// An empty national part stores nothing at all. A bare dial code would make
/// every untouched field look like a number the patient gave us — and
/// `contactPhoneKey` would start matching providers on it.
String joinPhone(CountryCode country, String national) {
  final n = national.trim();
  return n.isEmpty ? '' : '${country.dialCode} $n';
}

/// Phone entry with a country picker (design: `dialcodes.jsx` `PhoneInput`).
///
/// `.phone-field` — a dial-code button that opens the country sheet, then the
/// national number. [controller] holds the whole value (`+20 10 1234 5678`), so
/// call sites keep reading one string; the split is this widget's business.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.hint = kPhoneHintExample,
    this.onChanged,
    this.autofocus = false,
  });

  /// The full value, dial code included.
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;
  final bool autofocus;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late CountryCode _country;
  late final TextEditingController _national;

  @override
  void initState() {
    super.initState();
    final parsed = splitPhone(widget.controller.text);
    _country = parsed.country;
    _national = TextEditingController(text: parsed.national);
    widget.controller.addListener(_pullFromOwner);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_pullFromOwner);
    _national.dispose();
    super.dispose();
  }

  /// The owner can rewrite the value out from under us — a profile loading, or
  /// a form resetting. Follow it without clobbering what is being typed.
  void _pullFromOwner() {
    if (!mounted) return;
    final parsed = splitPhone(widget.controller.text, fallback: _country);
    if (parsed.national == _national.text && parsed.country == _country) return;
    setState(() {
      _country = parsed.country;
      _national.text = parsed.national;
    });
  }

  void _push() {
    final next = joinPhone(_country, _national.text);
    if (widget.controller.text != next) {
      widget.controller.removeListener(_pullFromOwner);
      widget.controller.text = next;
      widget.controller.addListener(_pullFromOwner);
    }
    widget.onChanged?.call();
  }

  Future<void> _pickCountry() async {
    final s = AppScope.of(context);
    final picked = await showAppSheet<CountryCode>(
      context,
      textDirection: s.dir,
      builder: (_) => _DialCodeSheet(s: s, current: _country),
    );
    if (picked == null || !mounted) return;
    setState(() => _country = picked);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // `.phone-field { align-items: stretch }`. Stretch needs a bounded height,
    // which a form column does not give it, so the row takes its height from
    // the taller child. That is the number field — which means the pair also
    // grows together under a large text scale, rather than the design's fixed
    // 54 clipping the text.
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          label: s.strings.common.ph_country_of(_country.dialCode),
          excludeSemantics: true,
          child: Pressable(
            onTap: _pickCountry,
            child: Container(
              // `.dial-code { padding: 0 14px }`; the height comes from the row.
              constraints: const BoxConstraints(minHeight: 54),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.border, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(countryFlagEmoji(_country.value), style: const TextStyle(fontSize: 20, height: 1)),
                const SizedBox(width: 8),
                // The dial code is digits: LTR in Arabic too.
                Text(_country.dialCode,
                    textDirection: TextDirection.ltr,
                    style: Typo.num(size: FS.lg, weight: FontWeight.w600, color: T.fg1)),
                const SizedBox(width: 1),
                const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
              ]),
            ),
          ),
        ),
        // `.phone-field { gap: 10px }`.
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _national,
            autofocus: widget.autofocus,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            // FR-213: Arabic-Indic digits fold on the way in, everywhere a number
            // is captured.
            onChanged: (v) {
              final folded = foldPhoneDigits(v);
              if (folded != v) {
                _national.value = TextEditingValue(
                  text: folded,
                  selection: TextSelection.collapsed(offset: folded.length),
                );
              }
              _push();
            },
            style: Typo.num(size: FS.lg, color: T.fg1),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: Typo.num(size: FS.lg, color: T.fg4),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(T.rMd),
                  borderSide: const BorderSide(color: T.border, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Searchable country sheet behind the dial-code button (`DialCodePicker`).
///
/// Over [CountryCode.all] — every ISO country, launch markets first, which is
/// the order the design's own curated list uses. Matches on the localized name,
/// the English name, the dial code and the ISO code.
class _DialCodeSheet extends StatefulWidget {
  const _DialCodeSheet({required this.s, required this.current});
  final PatientAppState s;
  final CountryCode current;

  @override
  State<_DialCodeSheet> createState() => _DialCodeSheetState();
}

class _DialCodeSheetState extends State<_DialCodeSheet> {
  final _search = TextEditingController();

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Arabic folding so "مصر" matches whichever spelling is stored, and the
  /// alif/ya/ta-marbuta variants a keyboard actually produces (`dcNorm`).
  static String _fold(String input) => input
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  @override
  Widget build(BuildContext context) {
    final locale = s.lang.value;
    final c = s.strings.common;
    final q = _fold(_search.text.trim());
    final digits = q.replaceAll('+', '');
    final items = CountryCode.all.where((country) {
      if (country.dialCode.isEmpty) return false;
      if (q.isEmpty) return true;
      return _fold(country.name(kCatalog, locale: locale)).contains(q) ||
          _fold(country.englishName).contains(q) ||
          (digits.isNotEmpty && country.dialCode.replaceAll('+', '').contains(digits)) ||
          country.value.toLowerCase().contains(q);
    }).toList();

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // `height: 82%`.
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: Text(c.ph_country, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              ),
              RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: c.a11y_close,
                  ghost: true,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textDirection: s.dir,
              style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1),
              decoration: InputDecoration(
                hintText: c.ph_country_search,
                hintStyle: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg4),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                prefixIcon: const Icon(LucideIcons.search, size: 17, color: T.fg3),
                prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: kMinTapTarget),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.border, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: BorderSide(color: s.accent.main, width: 1.5)),
              ),
            ),
          ),
          Flexible(
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(c.ph_no_match, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomInset(context, base: 34)),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: T.ink50),
                    itemBuilder: (_, i) {
                      final country = items[i];
                      final active = country == widget.current;
                      return Semantics(
                        button: true,
                        selected: active,
                        label: '${country.name(kCatalog, locale: locale)} ${country.dialCode}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, country),
                          behavior: HitTestBehavior.opaque,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: kMinTapTarget),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                              child: Row(children: [
                                Text(countryFlagEmoji(country.value), style: const TextStyle(fontSize: 24, height: 1)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    country.name(kCatalog, locale: locale),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(country.dialCode,
                                    textDirection: TextDirection.ltr,
                                    style: Typo.num(
                                        size: FS.sm, weight: FontWeight.w600, color: active ? s.accent.main : T.fg3)),
                                if (active) ...[
                                  const SizedBox(width: 8),
                                  Icon(LucideIcons.check, size: 18, color: s.accent.main),
                                ],
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
