/// Context every Balsm widget needs before it can render.
///
/// The widget previewer mounts a widget with none of the app's ambient
/// scopes, so a bare `@Preview` returning a kit widget throws on the first
/// `AccentScope.of` or `AppScope.of` lookup. These wrappers supply the same
/// stack `shell.dart` builds around the real app — Riverpod, [AppScope],
/// framework localizations, [Directionality], [AccentScope] — so a preview
/// shows what the app shows rather than a red error box.
///
/// ## Running it — do NOT use fvm for this one command
///
/// ```sh
/// cd app && ~/fvm/versions/3.41.9/bin/flutter widget-preview start
/// ```
///
/// `fvm flutter widget-preview start` fails with
/// `Unable to resolve package "app" with the given git parameters`. The
/// previewer builds a scaffold project and wires this one in by running
/// `dart pub add 'app:{"path":…}'`; the JSON descriptor loses its quotes on
/// the way through fvm's proxy, so pub reads it as a git descriptor and gives
/// up. Invoking the pinned SDK's `flutter` directly skips the proxy and
/// works — verified, it finds every preview in this directory. Everything
/// else in this repo still goes through fvm as normal.
///
/// ## Why these are top-level public functions
///
/// `@Preview(wrapper: …)` takes a `WidgetWrapper` and the annotation's
/// arguments must be const-evaluable: the wrapper has to be a **static,
/// non-private, top-level** function. A closure, a private helper, or an
/// instance method will not compile as an annotation argument.
///
/// ## No PHI, ever
///
/// Nothing here fabricates patient data, and neither should any preview that
/// uses it. `balsm_app/CLAUDE.md` forbids inventing sample PHI in code or
/// fixtures, so health screens get previewed in their empty, loading and
/// error states — which are the states most often left undesigned anyway.
/// Design-system primitives (the kit) carry no patient data at all, which is
/// exactly why they are the first thing worth previewing.
library;

import 'package:core/core.dart' show LanguageCode;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../kit.dart';

/// Default preview context: English, LTR, the app's violet accent.
///
/// Mirrors `shell.dart`'s wrapping order — [ProviderScope] outermost so
/// providers resolve, then [AppScope] so `AppScope.of` works, then the
/// MaterialApp that supplies Material ancestors (ink, text style, overlays)
/// plus the framework's own localizations.
Widget balsmPreview(Widget child) => _harness(child, lang: LanguageCode.en);

/// Arabic / RTL context, same widget.
///
/// Worth a second preview on anything directional rather than trusting it:
/// RTL breaks show up as mirrored padding and clipped rows, and this app
/// ships Arabic as a first-class locale, not a translation afterthought.
Widget balsmPreviewAr(Widget child) => _harness(child, lang: LanguageCode.ar);

/// A preview surface with the app's page background and comfortable padding,
/// for primitives that would otherwise render edge-to-edge on white.
Widget balsmPreviewPadded(Widget child) => _harness(
      Padding(padding: const EdgeInsets.all(16), child: child),
      lang: LanguageCode.en,
    );

Widget _harness(Widget child, {required LanguageCode lang}) {
  final state = PatientAppState()..lang = lang;
  return ProviderScope(
    child: AppScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang.value),
        // material_ui's bundle of the Cupertino/Material/Widgets delegates —
        // Flutter 3.47 moved them out of flutter_localizations, so listing
        // them individually now collides with that package's own names.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
        theme: ThemeData(scaffoldBackgroundColor: Colors.white, useMaterial3: true),
        home: Directionality(
          textDirection: state.dir,
          // Publishes `--app-accent` to the kit, the same as the real shell —
          // without it every accent-driven widget silently falls back to blue
          // and the preview lies about the shipped colour.
          child: AccentScope(
            accent: state.accent,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}
