import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The Home header and the shared avatar: an account with no name still gets
/// a face, and the greeting never trails an empty name line.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {PatientAppState? state}) => tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            state: state ?? PatientAppState(),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );

  group('Avatar', () {
    testWidgets('shows the initials when there are some', (tester) async {
      await pump(tester, const Avatar(initials: 'NA', color: Colors.teal));
      expect(find.text('NA'), findsOne);
      expect(find.byIcon(LucideIcons.userRound), findsNothing);
    });

    testWidgets('shows a person glyph, not a blank circle, with no initials', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const Avatar(initials: '', color: Colors.teal, semanticLabel: 'Your account'));
      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.userRound));
      expect(icon.color, Colors.white);
      expect(icon.size, closeTo(44 * 0.45, 0.01));
      expect(find.bySemanticsLabel('Your account'), findsOne);
      handle.dispose();
    });

    testWidgets('an empty name gives no initials', (tester) async {
      expect(accountInitials(''), isEmpty);
    });
  });

  group('HomeGreeting', () {
    testWidgets('shows the greeting above the name', (tester) async {
      await pump(tester, const HomeGreeting(firstName: 'Noor'));
      expect(find.text('Good morning'), findsOne);
      final name = tester.widget<Text>(find.text('Noor'));
      expect(name.style?.fontSize, 19);
      expect(name.style?.fontWeight, FontWeight.w700);
      expect(
        tester.getTopLeft(find.text('Good morning')).dy,
        lessThan(tester.getTopLeft(find.text('Noor')).dy),
      );
    });

    testWidgets('shows the greeting alone when there is no name', (tester) async {
      await pump(tester, const HomeGreeting(firstName: '  '));
      expect(find.text('Good morning'), findsOne);
      expect(find.byType(Text), findsOne);
    });

    testWidgets('greets in Arabic', (tester) async {
      await pump(tester, const HomeGreeting(firstName: 'نور'), state: PatientAppState()..setLang(LanguageCode.ar));
      expect(find.text('صباح الخير'), findsOne);
      expect(find.text('نور'), findsOne);
    });
  });
}
