---
context: Identity & Access
plane: cross-plane
features:
  - "P001: account deletion request/cancel with grace period"
---

# deletion

Account-deletion FSM (active -> deletionRequested -> deletionCancelled) with grace window.

## Pre-confirm disclosure (FR-031 / FR-513)

The three columns on `DeleteAccountScreen` are a compliance artifact, not copy:
they must list exhaustively and accurately what is kept, deleted from Balsm's
servers, and wiped from the phone.

Care team appears in **both** Deleted and Wiped. It used to be device-only, so
naming it under Wiped alone was true; now that it is mirrored to Balsm's own
database (spec 003), a screen that still said only "wiped" would be a false
statement to the patient at the moment they are deciding.

**When any module starts storing user data on Balsm servers, this screen is part
of that change.** So is `DeletionPurgeJob`, which hardcodes every context it
purges — data that is not purged there outlives the account regardless of what
this screen promises.

