import '../value_objects/user_id.dart';
import 'app_event.dart';

/// Emitted after the user's preferred language is successfully changed.
///
/// Listeners use this to update Directionality / reload translations.
/// Carries no PHI — only opaque user id and BCP-47 language tags.
class LanguageChanged extends AppEvent {
  final UserId userId;
  final String oldLanguage;
  final String newLanguage;

  const LanguageChanged({
    required this.userId,
    required this.oldLanguage,
    required this.newLanguage,
  });

  @override
  String get eventName => 'language_changed';

  @override
  Map<String, dynamic> toJson() => {
        'userId': userId.value,
        'oldLanguage': oldLanguage,
        'newLanguage': newLanguage,
      };
}
