---
context: Personal Health
plane: consumer
features:
  - "P001: emergency card + public QR token mint/resolve/revoke (client-side encryption)"
  - "P001: permanent medical-profile QR — ttl 0, keystore-held key, in-place ciphertext refresh so the QR never changes while scans stay current"
---

# emergency_card

Emergency card snapshot + QR tokens. Decryption key travels in the URL fragment - never sent to the server.

Permanent minting is **offline-first**: the jti (CSPRNG UUIDv4) and AES key are
generated on-device, so the QR renders, shares, and saves to the gallery with
no connectivity; the server learns about the token when the background sync
lands (`mint` is idempotent for a client-supplied `token_id`).

The permanent QR doubles as the patient's **stable profile identity token** —
bookings, emergency staff, and delegations can bind to its `jti`. Minting does
NOT require a completed medical profile; an empty card still mints and fills
in via refresh as data is added.

Tokens are temporary (1h/6h/24h/7d, countdown + auto-expiry) or **permanent** (ttl 0):
a permanent QR's URL never changes; its `{jti, key, etag}` live in the platform
keystore (`PermanentQrStore`) and `RefreshPermanentQrUseCase` re-encrypts the
current snapshot with the same key — on app start and sheet open — whenever the
snapshot etag drifts, so a scan always shows current data.
