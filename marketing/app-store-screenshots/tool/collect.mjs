#!/usr/bin/env node
// Maps docshots captures into the store screenshot tree.
//
// `app/tool/docshots.dart` photographs every screen of the app in every
// language and names them by what they ARE (04_home, 06_medications). A store
// deck cares about what each slide SELLS, and slide order changes with the
// pitch — so the mapping lives here, next to the deck, rather than being baked
// into the capture tool.
//
// Usage:
//   node tool/collect.mjs <captures-dir> <deck>
//   deck: iphone | ipad | android | android-7 | android-10
//
// <captures-dir> is the out-dir given to docshots; it holds <lang>/<name>.png.

import { readFileSync, existsSync, mkdirSync, copyFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";

const LOCALES = ["en", "ar"];

// Which capture sells which slide, in deck order. Keep these in step with the
// headlines in app-store-screenshots.json — slide 1 is the only one most people
// ever see, so it leads with the daily check-in.
const DECKS = {
  "iphone":     { dest: "apple/iphone",         shots: ["04_home", "05_care_map", "09_trends", "11_self_log", "12_checkin_step1_mood"] },
  "ipad":       { dest: "apple/ipad",           shots: ["04_home", "05_care_map", "09_trends", "11_self_log", "12_checkin_step1_mood"] },
  // The map needs the emulator on GPS-only (`settings put secure location_mode 1`):
  // high-accuracy mode makes Play Services throw a Location Accuracy consent
  // dialog over the map every time it opens. See docs/screenshots.md.
  "android":    { dest: "android/phone",        shots: ["04_home", "05_care_map", "09_trends", "11_self_log", "12_checkin_step1_mood"] },
  "android-7":  { dest: "android/tablet-7/portrait",  shots: ["08_records", "04_home"] },
  "android-10": { dest: "android/tablet-10/portrait", shots: ["08_records", "04_home"] },
};

const [capturesDir, deckName] = process.argv.slice(2);
if (!capturesDir || !DECKS[deckName]) {
  console.error(`usage: node tool/collect.mjs <captures-dir> <${Object.keys(DECKS).join("|")}>`);
  process.exit(64);
}

const deck = DECKS[deckName];
let copied = 0;
const missing = [];

for (const locale of LOCALES) {
  deck.shots.forEach((shot, i) => {
    const from = join(capturesDir, locale, `${shot}.png`);
    const to = join("public", "screenshots", deck.dest, locale, `${String(i + 1).padStart(2, "0")}.png`);
    if (!existsSync(from)) {
      missing.push(`${locale}/${shot}.png`);
      return;
    }
    mkdirSync(dirname(to), { recursive: true });
    copyFileSync(from, to);
    copied++;
  });
}

console.log(`${deckName}: copied ${copied} file(s) into public/screenshots/${deck.dest}/<locale>/`);
if (missing.length) {
  console.log(`missing ${missing.length} capture(s) under ${capturesDir}:`);
  for (const m of missing) console.log("  ", m);
  const langs = existsSync(capturesDir) ? readdirSync(capturesDir) : [];
  console.log(langs.length ? `  (captures dir holds: ${langs.join(", ")})` : "  (captures dir does not exist)");
}
