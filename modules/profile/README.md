---
context: Personal Health
plane: consumer
features:
  - "P001: on-device health profile - blood type, allergies, chronic conditions, emergency contacts"
---

# profile

HealthProfile aggregate (PHI, on-device only via SQLCipher). Max 50 allergies / 3 emergency contacts enforced in use cases; publishes HealthProfileUpdated.
