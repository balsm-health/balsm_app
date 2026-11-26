import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/screens/map_view.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// The signed-in user as the app shell publishes it: set on sign-in, null on
/// sign-out.
class _Session extends Notifier<UserId?> {
  @override
  UserId? build() => const UserId.value('user-a');

  UserId? get user => state;

  set user(UserId? value) => state = value;
}

final _session = NotifierProvider<_Session, UserId?>(_Session.new);

/// The map's search, camera and "search this area" offer outlive the route but
/// not the account. Every value is synthetic.
void main() {
  ProviderContainer container() {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [currentUserIdProvider.overrideWith((ref) => ref.watch(_session))],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the search, camera and pan offer reset when another account signs in', () {
    final c = container();
    c.read(careSearchProvider.notifier)
      ..typeText('test text')
      ..toggleType(CareEntityType.clinic);
    c.read(mapViewProvider.notifier).remember(const LatLng(1, 2), 12, placed: true);
    expect(c.read(careSearchProvider).text, 'test text');
    expect(c.read(mapViewProvider), isNotNull);

    c.read(_session.notifier).user = null;
    expect(c.read(careSearchProvider), const CareSearch(), reason: 'sign-out');
    expect(c.read(mapViewProvider), isNull);
    expect(c.read(mapPanProvider), const MapPan());

    c.read(_session.notifier).user = const UserId.value('user-b');
    expect(c.read(careSearchProvider).text, isEmpty, reason: 'the next user starts clean');
    expect(c.read(careSearchProvider).types, isEmpty);
  });

  test('text typed just before sign-out is not applied to the next account', () async {
    final c = container();
    final sub = c.listen(careSearchProvider, (_, __) {});
    addTearDown(sub.close);
    c.read(careSearchProvider.notifier).typeText('typed before sign-out');

    c.read(_session.notifier).user = null;
    await Future<void>.delayed(CareSearchNotifier.typingPause + const Duration(milliseconds: 100));

    expect(c.read(careSearchProvider).text, isEmpty, reason: 'the pending typing pause was cancelled');
  });

  test('clearing the text while the typing pause is pending leaves it cleared', () async {
    final c = container();
    final sub = c.listen(careSearchProvider, (_, __) {});
    addTearDown(sub.close);
    c.read(careSearchProvider.notifier)
      ..typeText('abc')
      ..clearText();
    await Future<void>.delayed(CareSearchNotifier.typingPause + const Duration(milliseconds: 100));

    expect(c.read(careSearchProvider).text, isEmpty, reason: 'the typed text must not come back after the pause');
  });
}
