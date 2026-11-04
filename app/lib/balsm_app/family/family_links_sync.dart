import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pulls the family links — there is no push, so this is how the phone learns
/// of a request or an approval, and when it re-seals a shared card that went
/// stale. The first read pulls by itself; later ones ask for a fresh pull.
void pullFamilyLinks(WidgetRef ref) {
  if (ref.exists(familyLinksProvider)) {
    ref.read(familyLinksProvider.notifier).refresh();
  } else {
    ref.read(familyLinksProvider);
  }
}
