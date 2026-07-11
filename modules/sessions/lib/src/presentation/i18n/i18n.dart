import 'messages.i69n.dart';
import 'messages_ar.i69n.dart';

export 'messages.i69n.dart';

/// Typed message bundle for the requested locale. Arabic (any `ar-*`)
/// resolves to the single Arabic bundle; everything else falls back to
/// English. `Messages_ar extends Messages`, so untranslated keys degrade
/// to English at the class level. Module-internal — not exported by the
/// barrel; each module owns its own strings.
Messages sessionsMessagesOf(String locale) =>
    locale.startsWith('ar') ? const Messages_ar() : const Messages();
