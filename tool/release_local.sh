#!/usr/bin/env bash
# Builds a release on this Mac and uploads it to the stores, the same way the
# store jobs in .github/workflows/release.yml do: the fallback for when the
# pipeline cannot. Nothing is submitted for review; each upload is finished in
# its console as usual (docs/releasing.md → Store uploads).
#
#   tool/release_local.sh <alpha|beta|production> --build-number=N [options]
#
#   --stores=ios,play,huawei   which stores (default: all three; production
#                              also deploys `web`, app.balsm.health)
#   --build-number=N           required: above every build already uploaded
#                              (the script checks Play's highest versionCode)
#   --skip-build               upload what dist/local/ already holds
#   --allow-dirty              build with uncommitted changes (not for production)
#   --dry-run                  check the config and print the plan; build and
#                              upload nothing
#
# Channel → backend and store destination, as in CI:
#   alpha       staging   TestFlight · Play internal (released) · AppGallery draft
#   beta        staging   TestFlight · Play closed testing `alpha` (released) · AppGallery draft
#   production  prod      TestFlight · Play production (draft) · AppGallery draft
#                         · web: app.balsm.health (Cloudflare Worker)
#
# Secrets come from .env.release in the checkout (git-ignored; start from
# .env.release.example), or the file named by $BALSM_RELEASE_ENV. Mode 600,
# KEY=value
# lines (never sourced). A value written as `keychain:<service>` is read from
# the login keychain (`security add-generic-password -s <service> -a "$USER" -w`
# stores one); `file:<path>` reads the first line of that file.
# The keys it reads are in docs/releasing.md → Releasing from a Mac.
#
# Signing material is used where it lies: the distribution certificate goes
# into a temporary keychain deleted at the end, the App Store profile is
# installed only for the build, and key.properties is written for the build
# and removed after.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "release: error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
note() { echo "    $*"; }

CHANNEL=""
STORES=""
BUILD_NUMBER=""
SKIP_BUILD=false
ALLOW_DIRTY=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    alpha|beta|production) CHANNEL="$arg" ;;
    --stores=*) STORES="${arg#*=}" ;;
    --build-number=*) BUILD_NUMBER="${arg#*=}" ;;
    --skip-build) SKIP_BUILD=true ;;
    --allow-dirty) ALLOW_DIRTY=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) die "unknown argument: $arg (see --help)" ;;
  esac
done
[ -n "$CHANNEL" ] || die "name the channel: alpha, beta or production (see --help)"
if [ -z "$STORES" ]; then
  if [ "$CHANNEL" = production ]; then STORES="ios,play,huawei,web"; else STORES="ios,play,huawei"; fi
fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "--build-number=N is required (a positive integer above every uploaded build)"
has() { case ",$STORES," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
for s in ${STORES//,/ }; do case "$s" in ios|play|huawei|web) ;; *) die "unknown store: $s" ;; esac; done
if has web && [ "$CHANNEL" != production ]; then die "web deploys production only (app.balsm.health serves the prod build)"; fi

case "$CHANNEL" in
  alpha)      ENVF=staging; PLAY_TRACK=internal;   PLAY_STATUS=completed ;;
  beta)       ENVF=staging; PLAY_TRACK=alpha;      PLAY_STATUS=completed ;;
  production) ENVF=prod;    PLAY_TRACK=production; PLAY_STATUS=draft ;;
esac
BUILD_NAME="$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' app/pubspec.yaml)"
[ -n "$BUILD_NAME" ] || die "no version in app/pubspec.yaml"
LABEL="v$BUILD_NAME-$CHANNEL (build $BUILD_NUMBER, local)"
DIST="$ROOT/dist/local"

# ── Config ────────────────────────────────────────────────────────────────
# .env.release in this checkout (git-ignored), or the file $BALSM_RELEASE_ENV names.
CONFIG="${BALSM_RELEASE_ENV:-$ROOT/.env.release}"
[ -f "$CONFIG" ] || die "no credentials file: cp .env.release.example .env.release and fill it in (docs/releasing.md → Releasing from a Mac)"
case "$(cd "$(dirname "$CONFIG")" && pwd)/" in
  "$ROOT"/*) git check-ignore -q "$CONFIG" || die "$CONFIG is inside the repo but not git-ignored; it must never be committed" ;;
esac
[ "$(stat -f '%Lp' "$CONFIG")" = 600 ] || die "$CONFIG must be readable by you only: chmod 600 '$CONFIG'"
# KEY=value lines only; never sourced, so the file cannot run anything.
cfg() {
  local v
  v="$(sed -n "s/^$1=//p" "$CONFIG" | tail -1)"
  v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
  case "$v" in
    keychain:*) security find-generic-password -s "${v#keychain:}" -w 2>/dev/null || die "$1: keychain item '${v#keychain:}' not found" ;;
    file:*) local f="${v#file:}"; f="${f/#\~/$HOME}"; [ -f "$f" ] || die "$1: $f does not exist"; head -1 "$f" | tr -d '\r\n' ;;
    *) printf '%s' "${v/#\~/$HOME}" ;;
  esac
}
# ANDROID_KEY_PROPERTIES points at an existing key.properties; its storeFile,
# alias and passwords fill in whichever ANDROID_* keys the config leaves out.
KEYPROPS_SRC="$(cfg ANDROID_KEY_PROPERTIES)"
kp() { [ -n "$KEYPROPS_SRC" ] || return 0; [ -f "$KEYPROPS_SRC" ] || die "ANDROID_KEY_PROPERTIES: $KEYPROPS_SRC does not exist"
  sed -n "s/^$1=//p" "$KEYPROPS_SRC" | tail -1 | tr -d '\r\n'; }
android_cfg() { # <config key> <key.properties key>
  local v; v="$(cfg "$1")"
  if [ -z "$v" ]; then
    v="$(kp "$2")"
    # storeFile is relative to app/android/ in key.properties' own convention,
    # and to the file's folder when it sits elsewhere.
    if [ "$2" = storeFile ] && [ -n "$v" ] && [ "${v#/}" = "$v" ]; then
      local d; d="$(dirname "$KEYPROPS_SRC")"
      if [ -f "$d/$v" ]; then v="$d/$v"; else v="$d/$(basename "$v")"; fi
    fi
  fi
  [ -n "$v" ] || die "$1 is not set in $CONFIG (nor in ANDROID_KEY_PROPERTIES)"
  printf '%s' "$v"
}
need() { local v; v="$(cfg "$1")"; [ -n "$v" ] || die "$1 is not set in $CONFIG"; printf '%s' "$v"; }
need_file() { local v; v="$(need "$1")"; [ -f "$v" ] || die "$1: $v does not exist"; printf '%s' "$v"; }

step "Checking $CONFIG"
if has ios; then
  [ "$(uname)" = Darwin ] || die "iOS needs macOS"
  APPLE_TEAM_ID="$(need APPLE_TEAM_ID)"
  P12="$(need_file APPLE_DIST_CERT_P12)"
  P12_PASSWORD="$(need APPLE_DIST_CERT_PASSWORD)"
  PROFILE="$(need_file APPSTORE_PROFILE)"
  ASC_KEY_ID="$(need ASC_KEY_ID)"
  ASC_ISSUER_ID="$(need ASC_ISSUER_ID)"
  ASC_KEY_FILE="$(need_file ASC_PRIVATE_KEY_FILE)"
  note "iOS: team $APPLE_TEAM_ID, key $ASC_KEY_ID"
fi
if has play || has huawei; then
  KEYSTORE="$(android_cfg ANDROID_KEYSTORE storeFile)"
  [ -f "$KEYSTORE" ] || die "ANDROID_KEYSTORE: $KEYSTORE does not exist"
  ANDROID_KEY_ALIAS="$(android_cfg ANDROID_KEY_ALIAS keyAlias)"
  ANDROID_STORE_PASSWORD="$(android_cfg ANDROID_STORE_PASSWORD storePassword)"
  ANDROID_KEY_PASSWORD="$(android_cfg ANDROID_KEY_PASSWORD keyPassword)"
  note "Android: keystore $(basename "$KEYSTORE"), alias $ANDROID_KEY_ALIAS"
fi
if has play; then
  PLAY_JSON="$(need_file PLAY_SERVICE_ACCOUNT_JSON_FILE)"
  note "Play: $(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["client_email"])' "$PLAY_JSON")"
fi
if has huawei; then
  HUAWEI_CLIENT_ID="$(need HUAWEI_CLIENT_ID)"
  HUAWEI_CLIENT_SECRET="$(need HUAWEI_CLIENT_SECRET)"
  HUAWEI_APP_ID="$(need HUAWEI_APP_ID)"
  note "AppGallery: app $HUAWEI_APP_ID"
fi
if has web; then
  CLOUDFLARE_API_TOKEN="$(need CLOUDFLARE_API_TOKEN)"
  command -v npx >/dev/null || die "web needs npx (Node.js)"
  note "web: app.balsm.health (deploy/web/wrangler.jsonc)"
fi
SHARED_ENV="$(cfg SHARED_ENV_JSON_FILE)"

# ── Source ────────────────────────────────────────────────────────────────
step "Source"
COMMIT="$(git rev-parse --short HEAD)"
DIRTY="$(git status --porcelain --untracked-files=no)"
note "commit $COMMIT, version $BUILD_NAME, channel $CHANNEL → $ENVF backend"
if [ -n "$DIRTY" ]; then
  [ "$CHANNEL" != production ] || die "uncommitted changes: production is built from a committed, tagged commit only"
  $ALLOW_DIRTY || die "uncommitted changes (commit them, or pass --allow-dirty for a test build)"
  note "warning: building with uncommitted changes"
fi
if [ "$CHANNEL" = production ]; then
  git tag --points-at HEAD | grep -qx "v$BUILD_NAME" \
    || die "production builds a commit tagged v$BUILD_NAME (Promote makes it); HEAD is not"
fi

if $DRY_RUN; then
  step "Plan (dry run)"
  $SKIP_BUILD || {
    has ios && note "build  bin/balsm ipa-appstore balsm $ENVF --build-name=$BUILD_NAME --build-number=$BUILD_NUMBER"
    { has play || has huawei; } && note "build  bin/balsm aab/apk balsm $ENVF --build-name=$BUILD_NAME --build-number=$BUILD_NUMBER"
  }
  has ios && note "upload xcrun altool --upload-app → App Store Connect (TestFlight)"
  has play && note "upload tool/play_upload.sh → Play track $PLAY_TRACK ($PLAY_STATUS)"
  has huawei && note "upload tool/appgallery_upload.sh → AppGallery app $HUAWEI_APP_ID (draft version)"
  has web && note "deploy bin/balsm web balsm prod --base-href=/ → wrangler deploy → app.balsm.health, then smoke-check"
  exit 0
fi

# ── Clean-up of everything the build puts in place ──────────────────────────
WORK="$(mktemp -d)"; chmod 700 "$WORK"
KEYCHAIN=""; PROFILE_UUID=""; KEYPROPS_BACKUP=""; PLIST_BACKUP=""; SHARED_WRITTEN=false
cleanup() {
  [ -n "$KEYCHAIN" ] && security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  if [ -n "$PROFILE_UUID" ]; then
    rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision" \
          "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
  fi
  rm -f app/android/key.properties
  [ -n "$KEYPROPS_BACKUP" ] && mv "$KEYPROPS_BACKUP" app/android/key.properties || true
  [ -n "$PLIST_BACKUP" ] && mv "$PLIST_BACKUP" app/ios/signing/appstore.plist || true
  $SHARED_WRITTEN && rm -f app/env/shared.json || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Play refuses a versionCode it already has; find out before a long build.
if has play; then
  step "Checking Play's highest versionCode"
  HIGHEST="$(PLAY_SERVICE_ACCOUNT_JSON_FILE="$PLAY_JSON" python3 -I - <<'PY'
import base64, json, os, subprocess, tempfile, time, urllib.parse, urllib.request
sa = json.load(open(os.environ["PLAY_SERVICE_ACCOUNT_JSON_FILE"]))
b = lambda x: base64.urlsafe_b64encode(x).rstrip(b"=")
now = int(time.time())
msg = b(b'{"alg":"RS256","typ":"JWT"}') + b"." + b(json.dumps({"iss": sa["client_email"],
      "scope": "https://www.googleapis.com/auth/androidpublisher", "aud": sa["token_uri"],
      "iat": now, "exp": now + 600}).encode())
with tempfile.NamedTemporaryFile("w") as k:  # created 0600
    k.write(sa["private_key"]); k.flush()
    sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", k.name], input=msg, capture_output=True, check=True).stdout
tok = json.load(urllib.request.urlopen(sa["token_uri"], urllib.parse.urlencode({
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": (msg + b"." + b(sig)).decode()}).encode()))["access_token"]
base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/app.balsm.health/edits"
req = lambda url, method="GET": urllib.request.urlopen(urllib.request.Request(url, method=method, data=b"{}" if method == "POST" else None,
      headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"}))
edit = json.load(req(base, "POST"))["id"]
try:
    bundles = json.load(req(f"{base}/{edit}/bundles")).get("bundles", [])
    print(max([b["versionCode"] for b in bundles], default=0))
finally:
    req(f"{base}/{edit}", "DELETE")
PY
)" || die "could not read Play's bundles (is the service account invited in Play Console?)"
  note "highest uploaded: $HIGHEST"
  [ "$BUILD_NUMBER" -gt "$HIGHEST" ] || die "--build-number=$BUILD_NUMBER is not above Play's $HIGHEST"
fi

# ── Build ───────────────────────────────────────────────────────────────────
mkdir -p "$DIST"
if ! $SKIP_BUILD; then
  if [ ! -f app/env/shared.json ]; then
    [ -n "$SHARED_ENV" ] || die "app/env/shared.json is missing; set SHARED_ENV_JSON_FILE in $CONFIG"
    cp "$SHARED_ENV" app/env/shared.json; SHARED_WRITTEN=true
  fi
  step "Code generation"
  ./bin/balsm gen

  if has ios; then
    step "iOS: signing set-up"
    KEYCHAIN="$WORK/store-signing.keychain-db"
    KC_PASSWORD="$(openssl rand -hex 24)"
    security create-keychain -p "$KC_PASSWORD" "$KEYCHAIN"
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$KC_PASSWORD" "$KEYCHAIN"
    security import "$P12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN" >/dev/null
    security set-key-partition-list -S apple-tool:,apple: -k "$KC_PASSWORD" "$KEYCHAIN" >/dev/null
    EXISTING=()
    while IFS= read -r k; do EXISTING+=("$k"); done < <(security list-keychains -d user | sed 's/^ *"//; s/"$//')
    security list-keychains -d user -s "$KEYCHAIN" "${EXISTING[@]}"
    # The search list is restored by deleting the keychain (cleanup).
    security cms -D -i "$PROFILE" > "$WORK/profile.plist"
    UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$WORK/profile.plist")"
    PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$WORK/profile.plist")"
    for d in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
      mkdir -p "$d"
      [ -f "$d/$UUID.mobileprovision" ] || { cp "$PROFILE" "$d/$UUID.mobileprovision"; PROFILE_UUID="$UUID"; }
    done
    note "profile \"$PROFILE_NAME\""
    PLIST_BACKUP="$WORK/appstore.plist.orig"; cp app/ios/signing/appstore.plist "$PLIST_BACKUP"
    cat > app/ios/signing/appstore.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key><dict>
    <key>app.balsm.health</key><string>$PROFILE_NAME</string>
  </dict>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
    step "iOS: building the App Store IPA"
    rm -rf app/build/ios/ipa
    ./bin/balsm ipa-appstore balsm "$ENVF" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
    cp app/build/ios/ipa/*.ipa "$DIST/balsm-$CHANNEL-appstore.ipa"
  fi

  if has play || has huawei; then
    step "Android: signing set-up"
    [ -f app/android/key.properties ] && { KEYPROPS_BACKUP="$WORK/key.properties.orig"; mv app/android/key.properties "$KEYPROPS_BACKUP"; }
    (umask 077; cat > app/android/key.properties <<EOF
storeFile=$KEYSTORE
storePassword=$ANDROID_STORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF
)
    rm -rf app/build/app/outputs/bundle app/build/app/outputs/flutter-apk
    if has play; then
      step "Android: building the app bundle"
      ./bin/balsm aab balsm "$ENVF" --no-apk --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
      find app/build/app/outputs/bundle -name '*.aab' -exec cp {} "$DIST/balsm-$CHANNEL.aab" \;
    fi
    if has huawei; then
      step "Android: building the APK"
      ./bin/balsm apk balsm "$ENVF" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
      cp app/build/app/outputs/flutter-apk/*.apk "$DIST/balsm-$CHANNEL.apk"
    fi
  fi
fi

if has web && ! $SKIP_BUILD; then
  step "Web: building for the domain root"
  ./bin/balsm web balsm "$ENVF" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" --base-href=/
  # The same refusal as CI: a wrong base path or a missing verification file
  # would take the site or deep links down.
  ( cd app/build/web
    grep -q '<base href="/">' index.html || die "index.html is not built for the domain root"
    [ -s main.dart.js ] || die "main.dart.js is missing"
    for f in .well-known/apple-app-site-association .well-known/assetlinks.json version/balsm.json; do
      python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" || die "$f is missing or not JSON"
    done )
fi

# ── Upload ──────────────────────────────────────────────────────────────────
if has ios; then
  step "App Store Connect (TestFlight)"
  IPA="$DIST/balsm-$CHANNEL-appstore.ipa"; [ -f "$IPA" ] || die "no $IPA (build it first)"
  mkdir -p "$WORK/private_keys"; cp "$ASC_KEY_FILE" "$WORK/private_keys/AuthKey_$ASC_KEY_ID.p8"
  API_PRIVATE_KEYS_DIR="$WORK/private_keys" xcrun altool --upload-app --type ios --file "$IPA" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
fi
if has play; then
  step "Google Play"
  AAB="$DIST/balsm-$CHANNEL.aab"; [ -f "$AAB" ] || die "no $AAB (build it first)"
  PLAY_SERVICE_ACCOUNT_JSON_FILE="$PLAY_JSON" tool/play_upload.sh --file "$AAB" \
    --track "$PLAY_TRACK" --status "$PLAY_STATUS" --name "$LABEL"
fi
if has huawei; then
  step "Huawei AppGallery"
  APK="$DIST/balsm-$CHANNEL.apk"; [ -f "$APK" ] || die "no $APK (build it first)"
  HUAWEI_CLIENT_ID="$HUAWEI_CLIENT_ID" HUAWEI_CLIENT_SECRET="$HUAWEI_CLIENT_SECRET" HUAWEI_APP_ID="$HUAWEI_APP_ID" \
    tool/appgallery_upload.sh --file "$APK"
fi

if has web; then
  step "Web: deploying app.balsm.health"
  [ -s app/build/web/index.html ] || die "no web build in app/build/web (build it first)"
  node --test deploy/web/worker.test.mjs
  CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" npx --yes wrangler@4 deploy -c deploy/web/wrangler.jsonc
  sleep 10
  for u in https://app.balsm.health/ https://app.balsm.health/version/balsm.json \
           https://app.balsm.health/.well-known/apple-app-site-association https://app.balsm.health/.well-known/assetlinks.json; do
    curl -fsS -o /dev/null --retry 5 --retry-delay 5 "$u" && note "ok   $u" || die "$u does not answer after the deploy"
  done
fi

step "Done: $LABEL from $COMMIT"
has ios && note "TestFlight: the build appears after processing; nothing submitted for review"
has play && note "Play: track $PLAY_TRACK ($PLAY_STATUS)"
has huawei && note "AppGallery: package on the version being edited; submit it in AppGallery Connect"
has web && note "Web: app.balsm.health is live"
note "Next CI release must use a higher build number than $BUILD_NUMBER, or Play refuses it."
