import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final deeplinkRouterProvider = Provider<DeeplinkRouter>((ref) {
  return DeeplinkRouter();
});

class DeeplinkRouter {
  final _appLinks = AppLinks();

  void listen(GoRouter router) {
    _appLinks.uriLinkStream.listen((uri) => _handle(uri, router));
  }

  void _handle(Uri uri, GoRouter router) {
    final path = uri.path;
    if (path.startsWith('/emergency/')) {
      final token = path.split('/emergency/').last.replaceFirst('public/', '');
      final key = uri.fragment.replaceFirst('k=', '');
      router.go('/emergency/public/$token', extra: {'key': key});
    } else if (path == '/account/delete') {
      router.go('/account/delete');
    } else if (path == '/account/delete-cancelled') {
      router.go('/account/delete-cancelled');
    } else if (path.startsWith('/auth/recovery')) {
      final token = uri.queryParameters['token'] ?? '';
      router.go('/auth/recovery/claim?token=$token');
    }
  }
}
