# balsm_lints

The analyzer config shared by every package in this repo: [very_good_analysis](https://pub.dev/packages/very_good_analysis)
plus the overrides that follow `CODING_STANDARDS.md`.

Use it from a package:

```yaml
# pubspec.yaml
dev_dependencies:
  balsm_lints:
    path: ../../packages/balsm_lints   # relative to the package

# analysis_options.yaml
include: package:balsm_lints/analysis_options.yaml
```

Change rules in `lib/analysis_options.yaml` only, with a comment saying why. See `CODING_STANDARDS.md` §10.
