# Store listing copy — Balsm patient app

Source of truth for App Store, Google Play and AppGallery text. Every string
here obeys the brand voice card (DesignSync → Brand · Voice & copy): **calm,
second-person, sentence case**. Explicitly not playful, not cold, not salesy —
so no emoji, no exclamation marks, no ALL CAPS, no "download now".

Positioning is the walkthrough's, already approved and shipping in-app:
*"Healthcare that finally belongs to us."*

Character counts are the platform maximums; each entry states its own length.

---

## Apple App Store

### App name — max 30

```
Balsm — Your health record
```
(26) Arabic: `بلسم — سجلك الصحي` (17)

Alternative if the em-dash renders badly: `Balsm: Your health record` (25).

### Subtitle — max 30

```
Arabic-first, private, offline
```
(30 — at the limit) Arabic: `عربي أولاً، خاص، ويعمل بلا إنترنت` (33)

Rejected: "Arabic-first, private by design" is 31 and will not save.

### Promotional text — max 170, editable without review

Use this for the coverage number, since it changes between imports.

```
Your records, your medications, and 34,000 nearby pharmacies, clinics and labs
across Egypt. Saved on your phone, and it works offline.
```
(135)

Arabic:
```
سجلاتك وأدويتك وأكثر من ٣٤ ألف صيدلية وعيادة ومعمل في مصر. محفوظة على هاتفك،
وتعمل دون إنترنت.
```

### Description — max 4000

```
Balsm is a health platform built in Egypt, for Egypt — Arabic-first, open
source, and owned by the people who use it.

Your health record lives on your phone, encrypted, and works with no signal.
You decide what leaves it.

WHAT YOU CAN DO

Keep your records in one place
Lab results, referrals, scans and prescriptions, organised and searchable in
Arabic or English.

Check in on how you feel
A two-minute daily self-report that builds a picture over time. It is your own
account of your health, not a clinical measurement.

Find care nearby
Hospitals, clinics, dentists, pharmacies, labs, scan centres and medical stores
across Egypt, on a map that works while you travel.

Track your medications
What you take, when you take it, and a dose history you can show a doctor.

Carry an emergency card
The details that matter in an emergency, shareable by QR when someone needs
them and not before.

PRIVACY, PLAINLY

Your health data is stored on your device and encrypted there. It is not
uploaded to our servers. Sharing happens only when you choose it, with whom you
choose, and you can stop it.

Balsm is open source. Anyone can read how it handles your data rather than take
our word for it.

BUILT FOR ARABIC

Arabic is the first language, not a translation. Right-to-left throughout,
Arabic numerals where they belong, and search that understands the different
ways a name is spelled.

A NOTE ON WHAT THIS IS

Balsm helps you keep and understand your own health information. It does not
diagnose, prescribe, or replace your doctor. If something is wrong, see a
clinician.
```
(~1,520)

### Keywords — max 100 chars, comma-separated, no spaces after commas

Do not repeat words already in the name or subtitle; Apple indexes those
separately.

```
صحة,طبيب,صيدلية,دواء,سجل طبي,عيادة,مستشفى,تحاليل,روشتة,مصر,health,pharmacy
```
(74)

Rationale: Arabic terms carry the most weight in the Egyptian storefront and
are under-served by competitors. `medical record`, `clinic`, `doctor` are
covered by the Arabic equivalents plus the English pair at the end.

### What's New — first release

```
First release.

Your health record, a daily check-in, your medications, an emergency card, and
a map of care across Egypt. Arabic-first, stored on your phone, works offline.
```

---

## Google Play

### Title — max 30

```
Balsm — Your health record
```
(26) Arabic: `بلسم — سجلك الصحي`

### Short description — max 80

```
Your health record, medications and nearby care. Arabic-first. Works offline.
```
(77)

Arabic:
```
سجلك الصحي وأدويتك ورعاية قريبة منك. عربي أولاً. يعمل دون إنترنت.
```

### Full description — max 4000

Same body as the App Store description above. Play renders no formatting, so
keep the bare section headers as written — they read as headings without markup.

Append at the end, which Play requires for health apps:

```
Balsm is not a medical device and does not provide medical advice.
```

### Tags (Play categories)

- Category: **Medical** (not Health & Fitness — Balsm holds records rather
  than tracking activity, and Medical is where users search for this)
- Tags: `Health records`, `Medical records`, `Pharmacy`, `Medication tracking`

---

## Huawei AppGallery

### App name — max 64
```
Balsm — Your health record
```

### Brief introduction — max 80
```
Your health record, medications and nearby care. Arabic-first. Works offline.
```

### Detailed description — max 8000
Reuse the App Store description.

AppGallery's Medical category requires qualification documents — a business
licence, and medical-device paperwork where it applies. Confirm what is needed
before writing more copy for this store.

---

## Taglines (for the site, ads and press — not store fields)

Ranked. All obey the voice card.

1. **Healthcare that finally belongs to us.** — the walkthrough line, already
   the strongest and already shipping.
2. Your health record. Yours to keep.
3. Arabic-first health, built in Egypt.
4. Your record lives on your phone.
5. Care nearby, in the language you think in.

Arabic:

1. رعاية صحية تخصّنا أخيراً.
2. سجلك الصحي. ملكك أنت.
3. صحة بالعربية، صُنعت في مصر.

---

## Screenshot plan

Six per device class, in this order — the first two are what most people see.

1. **Nearby care map** with clustered pins over Cairo. Most visually distinct
   screen and the clearest proof of coverage.
2. **Health record list** — bilingual entries visible.
3. **Daily check-in** mid-interaction.
4. **Medication list** with a dose history.
5. **Emergency card** with the QR.
6. **Privacy** — the on-device storage screen.

Caption each with a sentence-case line from the description; no marketing
overlay text beyond that.

Produce every screenshot in **both Arabic and English**, RTL mirrored. The
Egyptian storefront should default to the Arabic set.

Required sizes are in `docs/store/` alongside the existing iPad renders under
`uploads/balsm-ios-ipad-*` in the design project.

---

## Open items

- **34,000 in the promotional text** must match what ships. The count is
  34,797 today; re-check after any re-import, and prefer the promotional text
  field for it since that edits without review.
- **Arabic character counts** above are approximate — verify each against the
  store's own counter, which counts differently for combined characters. The
  Arabic subtitle is 33 and will need trimming to 30: try
  `عربي أولاً، خاص، بلا إنترنت` (27).
- **Age rating**: Balsm holds medical information but has no clinical advice,
  no user-generated content and no ads. Expect 4+ / Everyone, but the health
  questionnaire on both stores needs answering honestly about medical data.
- **Apple 5.1.1(ix)** requires a legal entity for healthcare apps — the listing
  cannot be submitted from an individual account regardless of this copy.
