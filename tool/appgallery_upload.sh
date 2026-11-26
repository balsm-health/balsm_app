#!/usr/bin/env bash
# Uploads a signed APK (or AAB) to Huawei AppGallery Connect as the app's new
# package, through the AppGallery Connect Publishing API. It never submits the
# version for review: the package lands on the version being edited in
# AppGallery Connect, and a person submits it there. See docs/releasing.md.
#
# Steps (https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-publishing-overview):
#   1. POST /api/oauth2/v1/token                      client id + secret → access token
#   2. GET  /api/publish/v2/upload-url/for-obs        → a signed upload URL + object id
#   3. PUT  <signed URL>                              the file itself
#   4. PUT  /api/publish/v2/app-file-info             attach the uploaded file to the app
#
# Usage:
#   tool/appgallery_upload.sh --file dist/balsm-alpha.apk [--app-id 1234567] [--dry-run]
#
# Environment:
#   HUAWEI_CLIENT_ID, HUAWEI_CLIENT_SECRET   AppGallery Connect API client (Connect API,
#                                            role "App administrator" or "Operations")
#   HUAWEI_APP_ID                            the app's id in AppGallery Connect (or --app-id)
#   AGC_API                                  API host; default https://connect-api.cloud.huawei.com
#
# --dry-run prints the requests it would make and touches no network, and
# needs none of the secrets. Requires bash, curl and python3 (JSON parsing).
set -euo pipefail

API="${AGC_API:-https://connect-api.cloud.huawei.com}"
APP_ID="${HUAWEI_APP_ID:-}"
FILE=""
DRY_RUN=false

die() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::appgallery: $*" >&2; else echo "appgallery: error: $*" >&2; fi
  exit 1
}
step() { echo "==> $*"; }
mask() { if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "$1" ]; then echo "::add-mask::$1"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:-}"; shift 2 ;;
    --file=*) FILE="${1#*=}"; shift ;;
    --app-id) APP_ID="${2:-}"; shift 2 ;;
    --app-id=*) APP_ID="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[ -n "$FILE" ] || die "--file is required"
case "$FILE" in
  *.apk) SUFFIX=apk ;;
  *.aab) SUFFIX=aab ;;
  *) die "$FILE is neither an .apk nor an .aab" ;;
esac
NAME="$(basename "$FILE")"

if $DRY_RUN; then
  SIZE="$( [ -f "$FILE" ] && wc -c < "$FILE" | tr -d ' ' || echo '<size>')"
  APP_ID="${APP_ID:-<HUAWEI_APP_ID>}"
  echo "appgallery: dry run, no network"
  step "POST $API/api/oauth2/v1/token  (grant_type=client_credentials, client_id=<HUAWEI_CLIENT_ID>)"
  step "GET  $API/api/publish/v2/upload-url/for-obs?appId=$APP_ID&fileName=$NAME&contentLength=$SIZE&suffix=$SUFFIX"
  step "PUT  <signed upload URL>  ($FILE, $SIZE bytes)"
  step "PUT  $API/api/publish/v2/app-file-info?appId=$APP_ID  (fileType=5, files=[{fileName: $NAME, fileDestUrl: <object id>}])"
  echo "appgallery: not submitting for review; a person submits the version in AppGallery Connect."
  exit 0
fi

[ -f "$FILE" ] || die "no such file: $FILE"
[ -n "$APP_ID" ] || die "HUAWEI_APP_ID (or --app-id) is not set"
[ -n "${HUAWEI_CLIENT_ID:-}" ] || die "HUAWEI_CLIENT_ID is not set"
[ -n "${HUAWEI_CLIENT_SECRET:-}" ] || die "HUAWEI_CLIENT_SECRET is not set"
command -v curl >/dev/null || die "curl is required"
command -v python3 >/dev/null || die "python3 is required"
SIZE="$(wc -c < "$FILE" | tr -d ' ')"

# json <python expression over `d`> — reads JSON on stdin, prints the value
# ('' when missing). Isolated mode: nothing from the working directory loads.
json() { python3 -I -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
try: v=eval(sys.argv[1], {}, {"d": d})
except Exception: v=""
print(json.dumps(v) if isinstance(v,(dict,list)) else ("" if v is None else v))' "$1"; }

# AppGallery answers 200 with an error inside: {"ret":{"code":N,"msg":"..."}}.
check_ret() { # body, what
  local code msg
  code="$(printf '%s' "$1" | json 'd.get("ret",{}).get("code","")')"
  msg="$(printf '%s' "$1" | json 'd.get("ret",{}).get("msg","")')"
  [ "$code" = "0" ] || die "$2 failed (ret.code=${code:-none}: ${msg:-no message})"
}

step "Getting an access token"
TOKEN_BODY="$(python3 -I -c 'import json,os; print(json.dumps({"grant_type":"client_credentials","client_id":os.environ["HUAWEI_CLIENT_ID"],"client_secret":os.environ["HUAWEI_CLIENT_SECRET"]}))')"
RESP="$(curl -sS --fail-with-body -X POST "$API/api/oauth2/v1/token" \
  -H 'Content-Type: application/json' --data-binary @- <<<"$TOKEN_BODY")" \
  || die "token request failed: $(printf '%s' "${RESP:-}" | head -c 300)"
TOKEN="$(printf '%s' "$RESP" | json 'd.get("access_token","")')"
[ -n "$TOKEN" ] || die "no access_token in the token response (check HUAWEI_CLIENT_ID / HUAWEI_CLIENT_SECRET): $(printf '%s' "$RESP" | json 'd.get("ret",d.get("error_description",""))')"
mask "$TOKEN"
AUTH=(-H "client_id: $HUAWEI_CLIENT_ID" -H "Authorization: Bearer $TOKEN")

step "Asking for an upload URL ($NAME, $SIZE bytes)"
RESP="$(curl -sS --fail-with-body -G "$API/api/publish/v2/upload-url/for-obs" "${AUTH[@]}" \
  --data-urlencode "appId=$APP_ID" --data-urlencode "fileName=$NAME" \
  --data-urlencode "contentLength=$SIZE" --data-urlencode "suffix=$SUFFIX")" \
  || die "upload-url request failed: $(printf '%s' "${RESP:-}" | head -c 300)"
check_ret "$RESP" "upload-url"
URL="$(printf '%s' "$RESP" | json 'd["urlInfo"]["url"]')"
OBJECT_ID="$(printf '%s' "$RESP" | json 'd["urlInfo"]["objectId"]')"
METHOD="$(printf '%s' "$RESP" | json 'd["urlInfo"].get("method","PUT")')"
{ [ -n "$URL" ] && [ -n "$OBJECT_ID" ]; } || die "upload-url response has no urlInfo.url / objectId"
mask "$URL"
# The signed URL only works with the headers it was signed with.
HEADERS=()
while IFS= read -r h; do [ -n "$h" ] && HEADERS+=(-H "$h"); done < <(
  printf '%s' "$RESP" | python3 -I -c 'import json,sys
for k,v in json.load(sys.stdin)["urlInfo"].get("headers",{}).items(): print(f"{k}: {v}")')

step "Uploading the file"
STATUS="$(curl -sS -o /dev/null -w '%{http_code}' -X "${METHOD:-PUT}" ${HEADERS[@]+"${HEADERS[@]}"} --data-binary "@$FILE" "$URL")" \
  || die "upload failed (network)"
case "$STATUS" in 2??) ;; *) die "upload answered HTTP $STATUS" ;; esac

step "Attaching the file to the app (draft, not submitted)"
INFO_BODY="$(NAME="$NAME" OBJECT_ID="$OBJECT_ID" python3 -I -c 'import json,os; print(json.dumps({"fileType":5,"files":[{"fileName":os.environ["NAME"],"fileDestUrl":os.environ["OBJECT_ID"]}]}))')"
RESP="$(curl -sS --fail-with-body -X PUT "$API/api/publish/v2/app-file-info?appId=$APP_ID" "${AUTH[@]}" \
  -H 'Content-Type: application/json' --data-binary @- <<<"$INFO_BODY")" \
  || die "app-file-info request failed: $(printf '%s' "${RESP:-}" | head -c 300)"
check_ret "$RESP" "app-file-info"
PKG="$(printf '%s' "$RESP" | json 'd.get("pkgVersion",[""])[0] if d.get("pkgVersion") else ""')"

echo "appgallery: uploaded $NAME${PKG:+ (package $PKG)}. Not submitted for review:"
echo "appgallery: open AppGallery Connect → My apps → the app → Version information, check it and submit."
