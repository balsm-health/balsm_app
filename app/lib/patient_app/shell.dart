import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'app_state.dart';
import 'kit.dart';
import 'tokens.dart';
import 'screens/home_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/meds_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/map_screen.dart';
import 'screens/auth_flow.dart';
import 'screens/records_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/quicklog_sheet.dart';
import 'screens/report_flow.dart';

/// Root of the patient app prototype. Owns [PatientAppState] and renders the
/// auth flow or the main tabbed app depending on `route`.
class PatientApp extends StatefulWidget {
  const PatientApp({super.key, required this.state});

  /// Pre-loaded state (persisted session + prefs). See [PatientAppState.load].
  final PatientAppState state;

  @override
  State<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends State<PatientApp> {
  late final PatientAppState state = widget.state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(scaffoldBackgroundColor: Colors.white, useMaterial3: true),
          // Clamp Dynamic Type so large system text never breaks layouts.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
              ),
              child: child!,
            );
          },
          home: Directionality(
            textDirection: state.dir,
            child: AdaptiveFrame(
              child: Scaffold(
                backgroundColor: Colors.white,
                body: state.route == 'app' ? const _MainApp() : const AuthRouter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive container. On phones the app is full-bleed; on tablet / desktop /
/// web it is centered in a phone-proportioned "device" card on a warm backdrop,
/// so the touch-first layout stays readable at any window size.
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({super.key, required this.child});
  final Widget child;

  static const _deviceW = 402.0;
  static const _deviceH = 874.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 600;
      if (phone) return child; // full-bleed, real safe areas

      final h = (c.maxHeight - 48).clamp(560.0, _deviceH);
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF1EFE7), Color(0xFFE4E2D8)],
          ),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: SizedBox(
              width: _deviceW,
              height: h,
              // Inject a synthetic device inset so spacers behave like hardware.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 56, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 56, bottom: 34),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(44),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 18))],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MainApp extends StatelessWidget {
  const _MainApp();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final hideTabBar = const {'trends', 'records', 'appts', 'rx'}.contains(s.tab);
    final screen = switch (s.tab) {
      'home' => const HomeScreen(),
      'trends' => const TrendsScreen(),
      'meds' => const MedsScreen(),
      'profile' => const ProfileScreen(),
      'map' => const MapScreen(),
      'records' => const RecordsScreen(),
      'appts' => const AppointmentsScreen(),
      'rx' => const PrescriptionsScreen(),
      _ => _Placeholder(title: s.tab),
    };
    return Column(children: [
      Expanded(child: screen),
      if (!hideTabBar) const _TabBar(),
    ]);
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEBFFFFFF),
        border: Border(top: BorderSide(color: T.border)),
      ),
      padding: EdgeInsets.only(bottom: 22 + MediaQuery.of(context).padding.bottom.clamp(0, 12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tab(id: 'home', icon: LucideIcons.home, label: s.t('tab_home')),
        _Tab(id: 'map', icon: LucideIcons.mapPin, label: s.t('tab_map')),
        const _FabTab(),
        _Tab(id: 'meds', icon: LucideIcons.pill, label: s.t('tab_meds')),
        _Tab(id: 'profile', icon: LucideIcons.user, label: s.t('tab_profile')),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.tab == id;
    final color = active ? s.accent.main : T.fg4;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => s.setTab(id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(label, style: Typo.body(ar: s.rtl).copyWith(
                fontSize: FS.xs2, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Center FAB tab — the daily check-in trigger (opens quick log).
class _FabTab extends StatelessWidget {
  const _FabTab();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () => showQuickLog(context, onFullCheckin: () => openCheckin(context)),
          child: Transform.translate(
            offset: const Offset(0, -22),
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                color: s.accent.main, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: s.accent.boxShadow,
              ),
              child: const Icon(LucideIcons.plus, size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Center(
      child: Text('${title[0].toUpperCase()}${title.substring(1)}\n(coming next)',
          textAlign: TextAlign.center, style: Typo.subhead(ar: s.rtl).copyWith(color: T.fg3)),
    );
  }
}

