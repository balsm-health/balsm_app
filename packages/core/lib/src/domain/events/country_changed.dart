import '../value_objects/user_id.dart';
import 'app_event.dart';

/// Emitted after the user's account country is successfully changed.
///
/// Listeners (e.g. home) use this to refresh locale / re-run disclosure.
/// Carries no PHI — only opaque user id and ISO country codes.
class CountryChanged extends AppEvent {
  final UserId userId;
  final String oldCountry;
  final String newCountry;

  const CountryChanged({
    required this.userId,
    required this.oldCountry,
    required this.newCountry,
  });

  @override
  String get eventName => 'country_changed';

  @override
  Map<String, dynamic> toJson() => {
        'userId': userId.value,
        'oldCountry': oldCountry,
        'newCountry': newCountry,
      };
}
