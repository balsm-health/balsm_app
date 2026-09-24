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
device on the desk. `bin/balsm run` (and every `melos run run:*` that wraps it)
looks up this machine's LAN address and passes it as `--dart-define=DEV_HOST=…`;
`FlavorConfig` then rewrites any preset whose host is `localhost`, `127.0.0.1`
or `::1`, keeping the scheme, port and path. A previously saved choice is
rewritten on read too, so a `Local` picked during a simulator session does not
outrank it.

Nothing else changes: other presets are untouched, a prod build refuses the
rewrite, and a plain `flutter run` or a CI build compiles no `DEV_HOST` at all.

```bash
bin/balsm run balsm dev                      # LAN address, found automatically
bin/balsm run balsm dev --dev-host=mac.local # mDNS, survives a new DHCP lease
bin/balsm run balsm dev --dev-host=off       # leave localhost alone
```

Two things still have to be true on this machine: the API listens on all
interfaces (`http://0.0.0.0:5050`, not `localhost:5050`), and the firewall
lets the port through. iOS is already set up for it — `NSAllowsLocalNetworking`
and `NSLocalNetworkUsageDescription` are in `Info.plist`, and the phone asks
once for local-network permission.

### A constraint worth knowing

`--dart-define-from-file` stringifies non-primitive values with Dart's
`toString()`, not as JSON — `ENVS` reaches the app as
`[{name: Local, url: http://...}]`, unquoted. The parser splits on `, ` and
`: `, so **a name or URL containing `, ` or `: ` will not parse**. URLs are safe
(`://` and `:8080` have no space); names like `"EU, West"` are not.

## Variants

Any `shared<suffix>.json` works — pass it with `--servers=<stem>`:

```bash
dart run tool/build.dart ipa balsm dev --servers=shared.tunnel
```

A common one is `shared.tunnel.json`, adding a devtunnel and a LAN address for
testing against a machine on the desk. It is ignored like the rest, so create
it yourself when you want it.
