import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Design-system `Select` — a bordered dropdown field with a trailing chevron.
///
/// Two sizes: the default (`dense: false`), used by forms such as
/// [med_plan_form.dart]'s frequency/duration pickers, and the small DS
/// `Select size sm` (`dense: true`; 32pt tall, 1px border), used by the body
/// map's layer picker. Generic over the option value so callers keep their
/// own `enum`/`String` value types instead of stringly keys.
///
/// Type parameter is `V` (not `T`) — this file's [T] design-token class would
/// otherwise be shadowed by a same-named generic parameter.
class SelectField<V> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.semanticsLabel,
    this.dense = false,
  });

  final V value;

  /// Options as `(value, label)` — label is already localized by the caller.
  final List<(V, String)> items;
  final ValueChanged<V> onChanged;

  /// Accessible name for the field (e.g. "Layer"). Pass null where a visible
  /// field label already names it (forms with a `_FieldLabel` above).
  final String? semanticsLabel;

  /// DS `Select size sm` (32pt, 1px border) vs. the default form size.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(T.rMd),
      borderSide: BorderSide(color: T.border, width: dense ? 1 : 1.5),
    );
    final field = InputDecorator(
      decoration: InputDecoration(
        isDense: dense,
        filled: true,
        fillColor: Colors.white,
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 12),
        border: border,
        enabledBorder: border,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<V>(
          value: value,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
          style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(value: v, child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
    final label = semanticsLabel;
    // `explicitChildNodes` keeps the dropdown's own button/value semantics as
    // a separate descendant node instead of merging its text into [label] —
    // without it, a screen reader hears "Layer\nSkin" as one run-on label.
    return label == null ? field : Semantics(label: label, container: true, explicitChildNodes: true, child: field);
  }
}
