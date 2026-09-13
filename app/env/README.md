# Build-time environment config

Values here are compiled into the binary by `--dart-define-from-file`. They are
read once at startup by `FlavorConfig.resolve` (`packages/core/lib/src/config/flavor.dart`).

## Tracked vs local

| File | Tracked | What it holds |
|---|---|---|
| `<brand>/dev.json`, `staging.json`, `prod.json` | yes | per-environment, non-secret |
| `shared*.json` | **no — git-ignored** | server list + Sentry DSN |

`shared*.json` is ignored because it carries a Sentry DSN and whatever server
URLs a given machine points at, including private tunnels. Every developer
writes their own; nothing generates it for you.

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

`ENVS` entries appear in the Dev Config server picker, which is only reachable
in the `dev` and `staging` flavors.

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
