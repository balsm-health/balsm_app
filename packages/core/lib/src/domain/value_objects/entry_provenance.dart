import 'unique_id.dart';

/// Who did something to a patient entry (a record, a medication, a reading).
///
/// [self] is the account holder on this device. The others are people who
/// added, changed or shared one of the patient's entries: someone in the
/// family, a doctor, or a clinic or other care provider.
enum ProvenanceActorKind {
  self,
  family,
  doctor,
  clinic;

  /// Stable stored code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a stored code. Throws [FormatException] on an unknown one: an
  /// attribution that cannot be read must not be shown as somebody else's.
  static ProvenanceActorKind fromWire(String code) => values.firstWhere(
        (k) => k.name == code,
        orElse: () => throw FormatException('unknown provenance actor kind', code),
      );
}

/// What the actor did to the entry.
enum ProvenanceAction {
  added,
  edited,
  shared;

  /// Stable stored code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a stored code. Throws [FormatException] on an unknown one.
  static ProvenanceAction fromWire(String code) => values.firstWhere(
        (a) => a.name == code,
        orElse: () => throw FormatException('unknown provenance action', code),
      );
}

/// The actor of a [ProvenanceEvent].
///
/// Someone other than the patient is named one of two ways: by the
/// [displayName] they had when they acted (a family member's name, a clinic's
/// name), or by [careProviderId], a reference to an entry in the patient's
/// care team, whose current name the app looks up. At least one is present.
class ProvenanceActor {
  const ProvenanceActor._(this.kind, this.displayName, this.careProviderId);

  /// The account holder on this device.
  static const self = ProvenanceActor._(ProvenanceActorKind.self, null, null);

  /// Someone other than the patient. Throws [ArgumentError] for
  /// [ProvenanceActorKind.self], or when neither a name nor a care-team
  /// reference is given: an attribution must say who.
  factory ProvenanceActor.other(ProvenanceActorKind kind, {String? displayName, String? careProviderId}) {
    if (kind == ProvenanceActorKind.self) {
      throw ArgumentError.value(kind, 'kind', 'use ProvenanceActor.self');
    }
    final name = displayName?.trim();
    final ref = careProviderId?.trim();
    if ((name == null || name.isEmpty) && (ref == null || ref.isEmpty)) {
      throw ArgumentError('an actor other than the patient needs a name or a care-team reference');
    }
    return ProvenanceActor._(
      kind,
      name == null || name.isEmpty ? null : name,
      ref == null || ref.isEmpty ? null : ref,
    );
  }

  final ProvenanceActorKind kind;

  /// The name the actor had when they acted. Null for [self], and for an
  /// actor known only by [careProviderId].
  final String? displayName;

  /// Opaque reference to a member of the patient's care team.
  final String? careProviderId;

  bool get isSelf => kind == ProvenanceActorKind.self;

  @override
  bool operator ==(Object other) =>
      other is ProvenanceActor &&
      other.kind == kind &&
      other.displayName == displayName &&
      other.careProviderId == careProviderId;

  @override
  int get hashCode => Object.hash(kind, displayName, careProviderId);
}

/// One immutable line of an entry's history: [actor] did [action] at [at].
class ProvenanceEvent {
  const ProvenanceEvent({required this.id, required this.actor, required this.action, required this.at});

  /// The patient's own edit of an entry, stamped now ([at]).
  factory ProvenanceEvent.selfEdit(DateTime at) => ProvenanceEvent(
        id: UniqueId.uuidv7().value,
        actor: ProvenanceActor.self,
        action: ProvenanceAction.edited,
        at: at,
      );

  /// Identity of the event, so storing the same history twice adds nothing.
  final String id;
  final ProvenanceActor actor;
  final ProvenanceAction action;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is ProvenanceEvent && other.id == id && other.actor == actor && other.action == action && other.at == at;

  @override
  int get hashCode => Object.hash(id, actor, action, at);
}

/// Append-only history of who added, edited or shared an entry.
///
/// An entry the patient made themself and nobody else touched has no
/// history at all ([none]) and shows nothing. Events are only ever added
/// ([append]); none is changed or removed, and the store refuses to change
/// one that is already saved.
class EntryHistory {
  const EntryHistory([this._events = const []]);

  /// The patient's own entry: nobody else involved.
  static const none = EntryHistory();

  final List<ProvenanceEvent> _events;

  /// Every event in the order it was appended (oldest first).
  List<ProvenanceEvent> get events => List.unmodifiable(_events);

  bool get isEmpty => _events.isEmpty;

  /// The latest event by someone other than the patient — who the entry is
  /// shown as coming from. Null when only the patient touched it.
  ProvenanceEvent? get attribution {
    for (final e in _events.reversed) {
      if (!e.actor.isSelf) return e;
    }
    return null;
  }

  /// Whether someone other than the patient added, edited or shared it.
  bool get isAttributed => attribution != null;

  /// Whether anyone, the patient included, edited the entry.
  bool get wasEdited => _events.any((e) => e.action == ProvenanceAction.edited);

  /// Events newest first, as the history sheet lists them. Events at the same
  /// moment keep the later-appended one first.
  List<ProvenanceEvent> get newestFirst {
    final indexed = _events.indexed.toList()
      ..sort((a, b) {
        final byTime = b.$2.at.compareTo(a.$2.at);
        return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
      });
    return indexed.map((e) => e.$2).toList(growable: false);
  }

  /// This history with [event] added at the end.
  EntryHistory append(ProvenanceEvent event) => EntryHistory(List.unmodifiable([..._events, event]));

  /// The patient's edit, recorded only on an entry someone else is part of:
  /// an entry that was always the patient's own keeps no history.
  EntryHistory stampSelfEdit(DateTime at) => isAttributed ? append(ProvenanceEvent.selfEdit(at)) : this;

  @override
  bool operator ==(Object other) {
    if (other is! EntryHistory || other._events.length != _events.length) return false;
    for (var i = 0; i < _events.length; i++) {
      if (other._events[i] != _events[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_events);
}
