# Build-time environment config

Values here are compiled into the binary by `--dart-define-from-file`. They are
read once at startup by `FlavorConfig.resolve` (`packages/core/lib/src/config/flavor.dart`).

## Tracked vs local

| File | Tracked | What it holds |
|---|---|---|
| `<brand>/dev.json`, `staging.json`, `prod.json` | yes | per-environment, non-secret |
| `shared*.json` | **no — git-ignored** | server list + Sentry DSN |
| `shared.example.json` | yes | the template the above is copied from |

`shared*.json` is ignored because it carries a Sentry DSN and whatever server
URLs a given machine points at, including private tunnels. Every developer
keeps their own.

## First run

```bash
cp app/env/shared.example.json app/env/shared.json
```

That is enough to build — the template's values are real-shaped placeholders
that work as-is against a local server. Edit it once you have somewhere else to
point at. `shared.example.json` is the one `shared*` file that IS tracked (via a
negation in `.gitignore`), so keep fake values in it.

## Shape

`app/env/shared.json` — required, since every build passes
`--dart-define-from-file=env/shared.json`:

```json
{
  "ENVS": [
    { "name": "Local",      "url": "http://localhost:5000" },
    { "name": "Staging",    "url": "https://staging.example.com" },
    { "name": "Production", "url": "https://api.example.com" }
  ],
  "SENTRY_DSN": ""
}
```

Both keys tolerate being empty. An empty `ENVS` falls back to a single `Local`
preset at `http://localhost:5000`; an empty `SENTRY_DSN` disables Sentry. So a
checked-out repo builds and runs before you have filled anything in.

`SENTRY_DSN` is empty rather than a fake DSN in the template on purpose: empty
disables Sentry cleanly, whereas a plausible-looking fake one would have the SDK
initialise and then fail sending to a host that does not exist.

`ENVS` entries appear in the Dev Config server picker, which is only reachable
in the `dev` and `staging` flavors.

### `localhost` on a real device

A phone's `localhost` is the phone, so a `Local` preset reaches nothing from a
device on the desk — and nothing on the handset knows which machine is serving
it. The app therefore **asks the network, at runtime**: `DevHostLocator` sweeps
the device's own subnet for a machine answering `/api/v1/health` on the
preset's port, and points the client at the first one that does. Debug builds
only; a URL that names a real host is never probed and never rewritten.

Because it happens at runtime rather than at compile time, moving between
Wi-Fi networks or picking up a new DHCP lease costs a reconnect, not a
rebuild. A connection failure mid-session re-runs the lookup and replays the
request once (`DevHostInterceptor`), so the app follows the server when it
moves under a running session.

Order of candidates, cheapest first: the host found last time, then `DEV_HOST`
if the launch compiled one in, then loopback itself — which is the right
answer on a simulator and on desktop — and only then the sweep.

`DEV_HOST` is that optional hint, not a rewrite: `bin/balsm run` and the
`Flutter: dev host` preLaunchTask write this machine's address into
`app/env/dev_host.json` (git-ignored, generated), which both launch paths pass
with `--dart-define-from-file`. It turns the usual case into one request
instead of a sweep, and a stale value costs one failed probe.

```bash
bin/balsm run balsm dev                      # writes the hint, then launches
bin/balsm run balsm dev --dev-host=mac.local # mDNS name instead of an address
bin/balsm run balsm dev --dev-host=off       # no hint; the sweep does the work
bin/balsm devhost                            # rewrite the hint, launch nothing
```

Two things still have to be true on this machine: the API listens on all
interfaces (`http://0.0.0.0:5050`, not `localhost:5050`), and the firewall
lets the port through — the sweep finds nothing that is not actually
reachable. iOS is already set up for it: `NSAllowsLocalNetworking` and
`NSLocalNetworkUsageDescription` are in `Info.plist`, and the phone asks once
for local-network permission.
