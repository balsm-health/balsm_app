#!/usr/bin/env bash
# Uploads a signed app bundle to Google Play through the Play Developer API and
# puts it on a track. It never submits anything beyond what the track status
# says: `completed` releases to that (testing) track, `draft` leaves a draft a
# person rolls out in Play Console. See docs/releasing.md.
#
# Steps (https://developers.google.com/android-publisher/edits):
#   1. POST oauth2.googleapis.com/token             service-account JWT → access token
#   2. POST .../edits                               open an edit
#   3. POST upload/.../edits/<id>/bundles           the .aab → its versionCode
#   4. PUT  .../edits/<id>/tracks/<track>           one release with that versionCode
#   5. POST .../edits/<id>:commit                   publish the edit (or delete it on failure)
#
# Usage:
#   tool/play_upload.sh --file app.aab --track internal|alpha|beta|production \
#     [--status completed|draft] [--name "v1.2.0 (51)"] [--package app.balsm.health] [--dry-run]
#
# Environment:
#   PLAY_SERVICE_ACCOUNT_JSON_FILE   path to the service account's JSON key
#                                    (or PLAY_SERVICE_ACCOUNT_JSON: the JSON itself)
#
# --dry-run prints the requests it would make and touches no network, and
# needs no key. Requires bash, curl, openssl and python3.
set -euo pipefail

PACKAGE=app.balsm.health
FILE=""
TRACK=""
STATUS=completed
NAME=""
DRY_RUN=false
API=https://androidpublisher.googleapis.com

die() { echo "play: error: $*" >&2; exit 1; }
step() { echo "==> $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:-}"; shift 2 ;;
    --file=*) FILE="${1#*=}"; shift ;;
    --track) TRACK="${2:-}"; shift 2 ;;
    --track=*) TRACK="${1#*=}"; shift ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --status=*) STATUS="${1#*=}"; shift ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --name=*) NAME="${1#*=}"; shift ;;
    --package) PACKAGE="${2:-}"; shift 2 ;;
    --package=*) PACKAGE="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[ -n "$FILE" ] || die "--file is required"
case "$FILE" in *.aab) ;; *) die "$FILE is not an .aab" ;; esac
case "$TRACK" in internal|alpha|beta|production) ;; *) die "--track must be internal, alpha, beta or production" ;; esac
case "$STATUS" in completed|draft) ;; *) die "--status must be completed or draft" ;; esac

EDITS="$API/androidpublisher/v3/applications/$PACKAGE/edits"
if $DRY_RUN; then
  step "POST https://oauth2.googleapis.com/token  (service-account JWT, scope androidpublisher)"
  step "POST $EDITS"
  step "POST $API/upload/androidpublisher/v3/applications/$PACKAGE/edits/<id>/bundles?uploadType=media  ($FILE)"
  step "PUT  $EDITS/<id>/tracks/$TRACK  (status $STATUS${NAME:+, name \"$NAME\"})"
  step "POST $EDITS/<id>:commit"
  exit 0
fi

[ -f "$FILE" ] || die "$FILE does not exist"
for t in curl openssl python3; do command -v "$t" >/dev/null || die "$t is required"; done

WORK="$(mktemp -d)"
EDIT_ID=""
TOKEN=""
cleanup() {
  # An edit left open blocks nothing, but delete it so the console stays clean.
  if [ -n "$EDIT_ID" ] && [ -n "$TOKEN" ]; then
    curl -sS -o /dev/null -X DELETE "$EDITS/$EDIT_ID" -H "Authorization: Bearer $TOKEN" || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
chmod 700 "$WORK"

if [ -n "${PLAY_SERVICE_ACCOUNT_JSON_FILE:-}" ]; then
  [ -f "$PLAY_SERVICE_ACCOUNT_JSON_FILE" ] || die "PLAY_SERVICE_ACCOUNT_JSON_FILE: $PLAY_SERVICE_ACCOUNT_JSON_FILE does not exist"
  cp "$PLAY_SERVICE_ACCOUNT_JSON_FILE" "$WORK/sa.json"
elif [ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
  (umask 077; printf '%s' "$PLAY_SERVICE_ACCOUNT_JSON" > "$WORK/sa.json")
else
  die "set PLAY_SERVICE_ACCOUNT_JSON_FILE (or PLAY_SERVICE_ACCOUNT_JSON)"
fi

# JSON field from a file: json <file> <python expression on d>
json() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

step "Signing in as $(json "$WORK/sa.json" "d['client_email']")"
(umask 077; json "$WORK/sa.json" "d['private_key']" > "$WORK/key.pem")
TOKEN_URI="$(json "$WORK/sa.json" "d.get('token_uri') or 'https://oauth2.googleapis.com/token'")"
NOW="$(date +%s)"
HEADER="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)"
CLAIMS="$(EMAIL="$(json "$WORK/sa.json" "d['client_email']")" AUD="$TOKEN_URI" NOW="$NOW" python3 -I -c '
import json, os
n = int(os.environ["NOW"])
print(json.dumps({"iss": os.environ["EMAIL"], "scope": "https://www.googleapis.com/auth/androidpublisher",
                  "aud": os.environ["AUD"], "iat": n, "exp": n + 3600}, separators=(",", ":")), end="")' | b64url)"
SIG="$(printf '%s.%s' "$HEADER" "$CLAIMS" | openssl dgst -sha256 -sign "$WORK/key.pem" | b64url)"
rm -f "$WORK/key.pem"
RESP="$(curl -sS -X POST "$TOKEN_URI" \
  --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  --data-urlencode "assertion=$HEADER.$CLAIMS.$SIG")"
TOKEN="$(printf '%s' "$RESP" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')"
[ -n "$TOKEN" ] || die "sign-in failed: $RESP"
AUTH=(-H "Authorization: Bearer $TOKEN")

# call <method> <url> [curl args...] → body on stdout; fails on HTTP >= 400
call() {
  local method="$1" url="$2"; shift 2
  local out code
  out="$(curl -sS -w '\n%{http_code}' -X "$method" "$url" "${AUTH[@]}" "$@")"
  code="${out##*$'\n'}"; out="${out%$'\n'*}"
  [ "$code" -lt 400 ] || die "$method $url → HTTP $code: $out"
  printf '%s' "$out"
}

step "Opening an edit for $PACKAGE"
OUT="$(call POST "$EDITS" -H 'Content-Type: application/json' -d '{}')"
EDIT_ID="$(printf '%s' "$OUT" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["id"])')"

step "Uploading $(basename "$FILE") ($(wc -c < "$FILE" | tr -d ' ') bytes)"
OUT="$(call POST "$API/upload/androidpublisher/v3/applications/$PACKAGE/edits/$EDIT_ID/bundles?uploadType=media" \
  -H 'Content-Type: application/octet-stream' --data-binary "@$FILE")"
VERSION_CODE="$(printf '%s' "$OUT" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["versionCode"])')"
echo "    versionCode $VERSION_CODE"

step "Putting versionCode $VERSION_CODE on track $TRACK ($STATUS)"
BODY="$(TRACK="$TRACK" STATUS="$STATUS" VC="$VERSION_CODE" NAME="$NAME" python3 -I -c '
import json, os
r = {"versionCodes": [os.environ["VC"]], "status": os.environ["STATUS"]}
if os.environ["NAME"]: r["name"] = os.environ["NAME"]
print(json.dumps({"track": os.environ["TRACK"], "releases": [r]}))')"
call PUT "$EDITS/$EDIT_ID/tracks/$TRACK" -H 'Content-Type: application/json' -d "$BODY" > /dev/null

step "Committing the edit"
call POST "$EDITS/$EDIT_ID:commit" > /dev/null
EDIT_ID=""
echo "Uploaded versionCode $VERSION_CODE to Google Play track $TRACK ($STATUS)."
