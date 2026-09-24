import 'dart:developer' as developer;
import 'dart:io';

import 'package:balsm_api/balsm_api.dart' show ApiRoutes;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Finds the machine serving the dev API, at runtime, from the device.
///
/// A phone's `localhost` is the phone, so a `http://localhost:5050` preset
/// reaches nothing from a device on the desk. Nothing on the handset knows
/// which machine is serving it, so this asks the network: the device's own
/// subnet is swept for something answering the API's health route, and the
/// first machine that does becomes the host.
///
/// Runtime rather than a compile-time define, so moving between Wi-Fi networks
/// — or the router handing out a new lease overnight — costs a reconnect
/// instead of a rebuild.
///
/// Debug builds only. [resolve] returns its argument untouched in a release
/// build, on web, and for any URL whose host is not loopback, so a staging or
/// production URL is never probed and never rewritten.
class DevHostLocator {
  DevHostLocator({
    Future<bool> Function(String host, int port, Duration timeout)? probe,
    Future<List<String>> Function()? subnets,
    List<String>? aliases,
    this.probeTimeout = const Duration(milliseconds: 400),
    this.sweepBatch = 32,
  })  : _probe = probe ?? _healthProbe,
        _subnets = subnets ?? _localSubnets,
        aliases = aliases ?? defaultAliases;

  final Future<bool> Function(String host, int port, Duration timeout) _probe;
  final Future<List<String>> Function() _subnets;

  /// Per-host budget. Short: a machine that is up answers a LAN request in
  /// single-digit milliseconds, and an absent one has to time out 253 times.
  final Duration probeTimeout;

  /// How many hosts are probed at once. High enough to sweep a /24 in a couple
  /// of seconds, low enough not to exhaust the socket table.
  final int sweepBatch;

  static const Set<String> loopback = {'localhost', '127.0.0.1', '::1'};

  /// Addresses that mean "the machine running the emulator".
  ///
  /// An Android emulator does not share a network with its host: the AVD's
  /// Wi-Fi sits on 192.168.232.0/24 and the host is not on it, reachable only
  /// through an alias the emulator special-cases — 10.0.2.2 for the standard
  /// AVD, 10.0.3.2 for Genymotion. Sweeping the guest's own subnet can never
  /// find the host, so these are asked directly.
  static const List<String> androidEmulatorAliases = ['10.0.2.2', '10.0.3.2'];

  /// [androidEmulatorAliases] on Android, nothing elsewhere. A real handset
  /// pays one refused connection for them, which is cheaper than the sweep
  /// they save on an emulator.
  static List<String> get defaultAliases => Platform.isAndroid ? androidEmulatorAliases : const [];

  /// Tried after the cheap candidates and before the sweep.
  final List<String> aliases;

  /// The host found last time, tried first on the next lookup.
  ///
  /// Held in memory only. A cached address that is stale after a network
  /// change costs one failed probe before the sweep runs, whereas a persisted
  /// one would outlive the machine it names.
  String? lastKnown;

  /// [baseUrl] with its host replaced by whatever is actually serving, or
  /// unchanged when nothing is.
  Future<String> resolve(String baseUrl, {String? preferred}) async {
    if (!kDebugMode || kIsWeb) return baseUrl;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !loopback.contains(uri.host)) return baseUrl;

    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final host = await find(port, preferred: preferred);
    if (host == null) return baseUrl;
    return uri.replace(host: host).toString();
  }

  /// The machine answering on [port], or null.
  ///
  /// Ordered by how likely each candidate is and how much it costs to ask:
  /// the last known host, then whatever the caller preferred, then loopback
  /// itself — the right answer on a simulator and on desktop, and a failure in
  /// a millisecond everywhere else — then the emulator [aliases], and only
  /// then the sweep.
  Future<String?> find(int port, {String? preferred}) async {
    final started = DateTime.now();
    for (final candidate in [lastKnown, preferred, '127.0.0.1', ...aliases]) {
      if (candidate == null || candidate.isEmpty) continue;
      if (await _probe(candidate, port, probeTimeout)) {
        lastKnown = candidate;
        _log('serving on $candidate:$port');
        return candidate;
      }
    }

    final prefixes = await _subnets();
    if (prefixes.isEmpty) {
      // Nothing to sweep: no usable IPv4 interface. On a phone that means
      // Wi-Fi is off and only cellular is up, which the dev machine is not on.
      _log('no LAN interface to sweep — is the device on Wi-Fi?');
      return null;
    }
    _log('sweeping ${prefixes.map((p) => '$p.0/24').join(', ')} for :$port');

    for (final prefix in prefixes) {
      // .255 is broadcast and .0 is the network itself; neither is a host.
      final hosts = [for (var i = 1; i < 255; i++) '$prefix.$i'];
      for (var i = 0; i < hosts.length; i += sweepBatch) {
        final batch = hosts.sublist(i, (i + sweepBatch).clamp(0, hosts.length));
        final answers = await Future.wait(batch.map((h) async => await _probe(h, port, probeTimeout) ? h : null));
        final hit = answers.firstWhere((h) => h != null, orElse: () => null);
        if (hit != null) {
          lastKnown = hit;
          _log('found $hit:$port in ${DateTime.now().difference(started).inMilliseconds}ms');
          return hit;
        }
      }
    }
    _log('nothing answered $port on ${prefixes.join(', ')} — is the server '
        'bound to 0.0.0.0, and is the firewall open? (iOS: the local-network '
        'prompt must be allowed)');
    return null;
  }

  /// Dev-only breadcrumb. The locator is invisible when it works and baffling
  /// when it does not, and the reasons it fails — wrong network, a server on
  /// localhost only, a refused permission prompt — are all outside the app.
  static void _log(String message) => developer.log(message, name: 'balsm.devhost');

  /// Whether [host] serves the Balsm API.
  ///
  /// The health route rather than a bare TCP connect: plenty of things listen
  /// on a development port, and pointing the app at the wrong one fails later
  /// and less legibly than not finding it at all.
  static Future<bool> _healthProbe(String host, int port, Duration timeout) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://$host:$port',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      validateStatus: (_) => true,
    ));
    try {
      final res = await dio.get<dynamic>(ApiRoutes.health);
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }

  /// The `a.b.c` prefix of every network this device is on.
  ///
  /// Assumes a /24, which every home and office LAN a phone joins is. Cellular
  /// and VPN interfaces are skipped: the dev machine is not down there, and
  /// sweeping a carrier network would be both useless and rude.
  static Future<List<String>> _localSubnets() async {
    final prefixes = <String>{};
    final List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    } on SocketException catch (e) {
      // Some Android builds refuse to enumerate interfaces. Nothing to sweep
      // is a dead end, not a crash on the path that opens the app.
      _log('cannot list network interfaces: ${e.message}');
      return const [];
    }
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (name.startsWith('pdp_ip') || name.startsWith('utun') || name.startsWith('ipsec')) continue;
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('169.254.')) continue;
        final dot = ip.lastIndexOf('.');
        if (dot > 0) prefixes.add(ip.substring(0, dot));
      }
    }
    return prefixes.toList();
  }
}
