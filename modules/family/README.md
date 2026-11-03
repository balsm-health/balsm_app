---
context: Personal Health
plane: consumer
features:
  - "P003b: family member profiles managed on this device (add manually, edit, close), filed in groups"
  - "P003b: switching the active profile so every screen shows the chosen person's data"
---

# family

Member profiles the account holder manages from their own phone — children,
parents, neighbours — and the groups they are filed under ("My family",
"Neighbours", or one the patient adds). Each member is its own Personal Health
partition (`health_profile`, keyed by `HealthProfileId`); switching to one
re-binds core's active profile, it never merges data.

Everything stays on the device. Linking someone who has their own Balsm
account (QR + approval) belongs to Identity & Access and is not here.

## Layers

- `domain/` — `MemberGroup` (default groups carry a key and are named at
  display time), `FamilyMember` (read model of a member profile), `MemberDraft`
  (what the add/edit form collects, with its rules), `MemberTone`, and
  `groupFamily` (members sorted into their groups).
- `application/` — `FamilyMembersPort` (member profiles; the profile module
  owns them, so the app shell binds this port to it — this module never
  imports profile) and `MemberGroupsDataSource`; use cases to add, edit and
  close a member and to list the groups (defaults created lazily per account).
- `infrastructure/drift/` — `DriftMemberGroupsDataSource` over `member_group`.
- `presentation/` — Riverpod providers the app shell's screens watch.

The screens themselves are ported in the app shell
(`app/lib/balsm_app/screens/family/`), behind the `mother_child` flag.
