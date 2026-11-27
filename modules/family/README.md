---
context: Personal Health
plane: consumer
features:
  - "P003b: family member profiles managed on this device (add manually, edit, close), filed in groups"
  - "P003b: switching the active profile so every screen shows the chosen person's data"
  - "P003b: growth log per person — weight and height entered by hand, newest first (no charts)"
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

- `domain/` — `GrowthEntry` (one weight and/or height measurement on a
  day, within plausible bounds), `MemberGroup` (default groups carry a key
  and are named at display time), `FamilyMember` (read model of a member
  profile), `MemberDraft` (what the add/edit form collects, with its rules),
  `MemberTone`, and `groupFamily` (members sorted into their groups).
- `application/` — `FamilyMembersPort` (member profiles; the profile module
  owns them, so the app shell binds this port to it — this module never
  imports profile), `MemberGroupsDataSource` and `GrowthLogDataSource`
  (partitioned by `health_profile_id`, soft delete); use cases to add, edit
  and close a member, to list the groups (defaults created lazily per
  account) and to record a growth entry.
- `infrastructure/drift/` — `DriftMemberGroupsDataSource` over `member_group`,
  `DriftGrowthLogDataSource` over `growth_entry`.
- `presentation/` — Riverpod providers the app shell's screens watch.

The screens themselves are ported in the app shell
(`app/lib/balsm_app/screens/family/`), behind the `mother_child` flag.
