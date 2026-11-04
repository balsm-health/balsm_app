import 'package:account/account.dart';
import 'package:core/core.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profile/profile.dart';

/// Binds the family_link module's [OwnEmergencyCardReader] to the account
/// holder's own data: blood type, allergies, chronic conditions and emergency
/// contacts from their SELF health profile (profile module), name and date of
/// birth from their account details (account module). Composition only — the
/// modules never import each other. PHI stays in memory here; nothing is
/// logged.
class ProfileOwnEmergencyCard implements OwnEmergencyCardReader {
  ProfileOwnEmergencyCard({
    required HealthProfilesDataSource profiles,
    required Future<ProfileDetails?> Function() details,
    required UserId? Function() activeUser,
  })  : _profiles = profiles,
        _details = details,
        _activeUser = activeUser;

  final HealthProfilesDataSource _profiles;
  final Future<ProfileDetails?> Function() _details;
  final UserId? Function() _activeUser;

  @override
  Future<EmergencyCardPayload?> read() async {
    final user = _activeUser();
    if (user == null) return null;
    final ProfileDetails? details;
    try {
      details = await _details();
    } catch (_) {
      // Offline or signed out mid-read: leave any shared card as it is rather
      // than replace it with one missing the name and date of birth.
      return null;
    }
    final profile = await _profiles.getProfile(user);
    final joined = [details?.firstName, details?.lastName].whereType<String>().where((p) => p.isNotEmpty).join(' ');
    final contacts = [...?profile?.emergencyContacts]
      ..sort((a, b) => a.isPrimary == b.isPrimary ? 0 : (a.isPrimary ? -1 : 1));
    return EmergencyCardPayload(
      name: details?.displayName ?? (joined.isEmpty ? null : joined),
      dateOfBirth: details?.dateOfBirth,
      bloodType: profile?.bloodType?.code,
      allergies: [for (final a in profile?.allergies ?? const <Allergy>[]) a.name],
      conditions: [for (final c in profile?.conditions ?? const <ChronicCondition>[]) c.name],
      contacts: [for (final c in contacts) CardContact(name: c.name, phone: c.phone, relation: c.relation)],
    );
  }
}

/// The composition-root binding:
/// `ownEmergencyCardReaderProvider.overrideWith(profileOwnEmergencyCard)`.
OwnEmergencyCardReader profileOwnEmergencyCard(Ref ref) => ProfileOwnEmergencyCard(
      profiles: ref.watch(profileDataSourceProvider),
      details: () => ref.read(accountProfileUseCaseProvider).load(),
      activeUser: () => ref.read(currentUserIdProvider),
    );
