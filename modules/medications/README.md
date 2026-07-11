---
context: Personal Health
plane: consumer
features:
  - "P001: medication schedules + OS reminders, append-only dose history, missed-dose detection"
---

# medications

Medication aggregate + APPEND-ONLY DoseEvent history (corrections reference parents, never mutate). OS notification scheduler (30-day horizon, PHI-free bodies) and foreground missed-dose detector.
