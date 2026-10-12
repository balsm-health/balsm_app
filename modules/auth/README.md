---
context: Identity & Access
plane: cross-plane
features:
  - "P001: email OTP + social sign-in (Google/Apple), age gate, lockout, recovery claim"
---

# auth

Sign-in/sign-up flows, session aggregate (Unauthenticated | Authenticated | LockedOut), age gate, and account-recovery claim. Persists tokens in the OS keychain; publishes UserSignedIn/Out/Up on the EventBus.
