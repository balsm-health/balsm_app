---
context: Prescriptions
plane: consumer
features:
  - "P001: on-device prescription records with pharmacy reference codes (QR-rendered for dispensation)"
---

# prescriptions

Patient-held prescription records. PHI, on-device only (drift via
`PrescriptionsDataSource`). A prescription may carry a pharmacy `reference`
code, which the app renders as a QR for dispensation; self-recorded entries
have none.
