# Store screenshots

The App Store and Google Play images, exported from the claude.ai/design
**Balsm App** project's
[Store Screenshots v5](https://claude.ai/design/p/1173afbf-d8eb-42a5-84c3-79d8add96d4e?file=Store+Screenshots+v5.html).
**The design is the source of truth**: change the copy, layout or the app
screens inside the frames there, then re-export. Don't edit these PNGs by hand.

## Layout

The folders are the design's own export, unchanged, so a new export drops in
place:

    App Store/<en-US|ar-SA>/iPhone 6.3in 1206x2622/0N-<screen>.png
    App Store/<en-US|ar-SA>/iPad 13in 2064x2752/0N-<screen>.png
    App Store/<locale>/Featured artwork/…       editorial artwork sizes
    App Store/<locale>/Store previews/…          how the set reads in search and on the product page (reference, not uploaded)
    Google Play/<en-US|ar>/Phone 1080x1920/…
    Google Play/<locale>/Tablet 7in 1440x2560/…
    Google Play/<locale>/Tablet 10in 1800x3200/…
    Google Play/<locale>/Feature graphic 1024x500/…

Six screens per set: home, nearby, meds, trends, profile, brand.

## Re-export

1. Open the design file above and press **Download all (ZIP)**. It renders
   every frame at its exact store size and saves `Balsm Store Assets.zip`.
2. Unzip it over this folder:

   ```sh
   unzip -o ~/Downloads/"Balsm Store Assets.zip" -d /tmp/store
   cp -R "/tmp/store/Balsm Store Assets/." marketing/store-screenshots/
   ```

3. Remove the alpha channel. The browser saves RGBA even though every frame
   is opaque, and App Store Connect rejects screenshots that have one:

   ```sh
   find marketing/store-screenshots -name '*.png' -print0 | while IFS= read -r -d '' f; do
     magick "$f" -background white -alpha remove -alpha off -strip \
       -define png:exclude-chunk=date,time "PNG24:$f"
   done
   ```

The app screens inside the frames are the design project's own captures
(`screenshots/crop-*.png`, `tabP-*.png` there). To show newer UI, recapture
the app (`docs/screenshots.md`) and replace those files in the design project
before exporting.
