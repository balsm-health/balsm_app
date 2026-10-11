# Feature flags

A feature flag is a named on/off switch the app reads at run time, so a feature
can be turned on or off without shipping a build.

The app does not know which tool serves the flags. PostHog is wired today;
Firebase Remote Config, Branch or a JSON file on our own server can be added or
swapped in by writing one small class.

## How a flag gets its value

First one that answers wins:

1. **Dev Config override** — dev and staging builds only. Production ignores
   overrides, including one left on disk.
2. **Sources, in order** — today PostHog, then the build's `FEATURE_FLAGS`
   define. The answers are remembered on the device, so a launch with no
   network uses the last known values.
3. **The flag's fallback** — written in the code next to the flag.

Reading a flag never waits for the network. Sources are asked again on launch,
each time the app returns to the foreground, and when the patient changes their
analytics choice. A source that is unreachable changes nothing.

## The sync flags

All off by default, so nothing syncs until someone turns it on.

| Key | Controls |
|---|---|
| `sync` | Master switch. Off stops every type below. |
| `sync_care` | Care team |
| `sync_records` | Health records |
| `sync_rx` | Prescriptions |
| `sync_meds` | Medications |
| `sync_checkins` | Check-ins |
| `sync_symptoms` | Symptoms |
| `sync_vitals` | Vitals |
| `sync_medical` | Medical profile |
| `sync_appts` | Appointments |

A type syncs only when `sync` **and** its own flag are on. Only the care team
has a sync engine today: turning on any other type's flag does nothing, and the
app will not claim a cloud copy for it.

With care-team sync on, the patient's own switch in Storage & sync still
applies on top. With it off, that switch is hidden and the care team reads
"this device only". Changes made while sync is off are queued and sent when it
is turned back on.

Care-team sync covers a provider's text only. Attached files and links stay on
the device.

## Other flags

| Key | Default | Controls |
|---|---|---|
| `beta_banner` | on | The amber corner ribbon marking the release as a beta ("Beta" / "إطلاق تجريبي"). Turn it off when the app is declared stable. For store screenshots, build with `FEATURE_FLAGS=beta_banner=false`. |

## Turning a flag on

- **Everyone, remotely:** create a boolean flag with the same key in PostHog
  and roll it out. To sync the care team, both `sync` and `sync_care` must be
  on.
- **One build:** `--dart-define=FEATURE_FLAGS=sync=true,sync_care=true`
- **One device (dev/staging):** Dev Config → App feature flags. A tap cycles
  forced on → forced off → back to normal.

### PostHog and consent

Asking PostHog for flags sends it the device's analytics id. A patient who
opted out of analytics is therefore never asked about, and gets fallbacks (or
the build define). The same is true of the web build, which carries no PostHog
at all. A feature that must reach those users needs a source that does not
depend on analytics consent.

## Adding a flag for a new feature

In `app/lib/balsm_app/flags.dart`:

```dart
static const newThing = FeatureFlag('new_thing', fallback: false, label: 'New thing');
```

Add it to `AppFlags.all`, then read it:

```dart
if (flags.isOn(AppFlags.newThing)) { ... }
```

`flags` is `ref.watch(featureFlagsProvider)`, or `AppScope.of(context).flags`
in the patient app's screens, which rebuild when a flag changes.

Keys use letters, digits and underscores only. Choose the fallback that is safe
on a device that has never been online.

## Adding or swapping a tool

Implement `FeatureFlagSource` (`packages/core/lib/src/flags/`):

```dart
class RemoteConfigFlagSource implements FeatureFlagSource {
  @override
  String get name => 'remote_config';

  @override
  Future<void> refresh() => FirebaseRemoteConfig.instance.fetchAndActivate();

  @override
  Future<bool?> read(String key) async {
    final v = FirebaseRemoteConfig.instance.getValue(key);
    return v.source == ValueSource.valueStatic ? null : v.asBool();
  }
}
```

Return `null` from `read` when the tool has no value for the key, so the next
source or the fallback decides. Then add it to the `sources` list in
`app/lib/brands/balsm/main_balsm.dart`. Order is priority. Nothing else
changes.
