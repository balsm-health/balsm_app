import 'package:flutter/widgets.dart';

import 'i18n/messages.i69n.dart';
import 'i18n/messages_ar.i69n.dart';

/// Core's strings (`common.*`, `status.*`, `error.*`, …) in the language of [context].
///
/// The shared words (Cancel, Retry, Done, …) live here once; a module uses them rather than declaring its own.
/// Exported from `package:core/core.dart` by name only, because every module has its own `Messages` class.
Messages coreMessagesOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar' ? const Messages_ar() : const Messages();
