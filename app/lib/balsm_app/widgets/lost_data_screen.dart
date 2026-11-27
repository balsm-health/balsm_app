import 'dart:async';

import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';

import '../kit.dart';
import '../strings.dart';
import '../theme.dart';
import 'balsm_mark.dart';

/// Runs before the app when [checkDbKey] reports [DbKeyStatus.lost]: shows
/// [LostDataScreen] on its own and returns once the patient chose to start
/// fresh and the unreadable data was moved aside. The caller then opens the
/// database and starts the app as usual; its `runApp` replaces this one.
///
/// Without this the app started on a database it could not open: every read
/// failed, and sign-in hung on the disclosure check with no message (#172).
Future<void> recoverLostData({required String lang}) {
  final done = Completer<void>();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
      locale: Locale(lang),
      theme: balsmTheme(),
      home: LostDataScreen(
        lang: lang,
        onStartFresh: () async {
          await setAsideUnreadableData();
          if (!done.isCompleted) done.complete();
        },
      ),
    ),
  );
  return done.future;
}

/// Says the data saved before can't be opened and offers to start fresh,
/// with a second, explicit confirmation. Public for its widget test.
class LostDataScreen extends StatefulWidget {
  const LostDataScreen({required this.lang, required this.onStartFresh, super.key});

  /// `en` or `ar`: the prefs aren't loaded into an app state yet.
  final String lang;

  /// Moves the data aside; the screen shows progress until it completes.
  final Future<void> Function() onStartFresh;

  @override
  State<LostDataScreen> createState() => _LostDataScreenState();
}

class _LostDataScreenState extends State<LostDataScreen> {
  // View-local: which of the two steps is showing, and whether the move runs.
  bool _confirming = false;
  bool _busy = false;

  Future<void> _startFresh() async {
    setState(() => _busy = true);
    await widget.onStartFresh();
  }

  @override
  Widget build(BuildContext context) {
    final strings = stringsFor(widget.lang).boot;
    final rtl = LanguageCode.fromCode(widget.lang).isRtl;
    final app = (FlavorConfig.currentOrNull?.brand ?? AppBrand.balsm).nameIn(widget.lang);
    final title = _confirming ? strings.lost_confirm_t : strings.lost_t;
    final body = _confirming ? strings.lost_confirm_b(app) : strings.lost_b(app);
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      // The app's default accent (PatientAppState.accent): without a scope the
      // buttons would fall back to blue and look like another app.
      child: AccentScope(
        accent: Accent.violet,
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BalsmFlower(size: 52),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: FontSizes.headline,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: FontSizes.bodyLg, height: 1.5, color: AppColors.ink600),
                      ),
                      const SizedBox(height: 28),
                      if (!_confirming)
                        PButton(
                          strings.lost_start,
                          block: true,
                          large: true,
                          ar: rtl,
                          onTap: () => setState(() => _confirming = true),
                        )
                      else ...[
                        PButton(
                          strings.lost_confirm_yes,
                          block: true,
                          large: true,
                          ar: rtl,
                          variant: BtnVariant.danger,
                          onTap: _busy ? null : _startFresh,
                        ),
                        const SizedBox(height: 8),
                        PButton(
                          strings.lost_cancel,
                          block: true,
                          large: true,
                          ar: rtl,
                          variant: BtnVariant.ghost,
                          onTap: _busy ? null : () => setState(() => _confirming = false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
