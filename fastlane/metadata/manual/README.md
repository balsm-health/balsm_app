# Manual store-console fields

Values that `deliver` and `supply` cannot push, kept here so they are tracked,
diffable and covered by the pre-upload URL check rather than living only in
someone's browser session.

- `account_deletion_url.txt` — Play Console › Data safety › Data deletion.
  Google requires a URL reachable WITHOUT installing the app. Served by the
  Flutter web app at `/delete-account` (PublicDeleteScreen), which switches
  language in-app, so one URL covers both locales.
