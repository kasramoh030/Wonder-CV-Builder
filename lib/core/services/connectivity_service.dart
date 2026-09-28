import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device can reach the internet *right now*.
enum ConnectivityStatus {
  /// A reachability probe succeeded.
  online,

  /// A probe failed. Everything offline-capable in the app still works.
  offline,

  /// No probe has completed yet. Treated as offline by the UI so that the
  /// app never promises an online feature it cannot deliver.
  unknown;

  bool get isOnline => this == ConnectivityStatus.online;
}

/// Lightweight reachability probe.
///
/// Deliberately implemented with `dart:io` rather than a platform plugin:
///
/// * **No extra dependency and no extra permission.** A DNS lookup needs
///   nothing beyond the `INTERNET` permission the AI features already
///   require, unlike plugins that also read the current transport type.
/// * **It answers the question the UI actually asks.** An app that offers an
///   online feature needs to know "can I reach a server", not "is Wi-Fi
///   enabled" — a phone attached to a captive-portal Wi-Fi is *connected*
///   and still cannot reach the API.
/// * **It fails fast and quietly.** Probes are rate-limited and swallowed on
///   error, so a device that is permanently offline does not burn battery
///   or spin the logs.
class ConnectivityService {
  ConnectivityService({
    this.probeInterval = const Duration(seconds: 30),
    this.probeTimeout = const Duration(seconds: 4),
    List<String>? probeHosts,
  }) : probeHosts = probeHosts ?? const <String>['one.one.one.one', 'dns.google'];

  /// How often the service re-probes while the app is running.
  final Duration probeInterval;

  /// How long a single probe may take before it counts as a failure.
  final Duration probeTimeout;

  /// Hostnames tried in order. Two independent resolvers are used so a
  /// single blocked DNS provider does not look like "the internet is down".
  final List<String> probeHosts;

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _status = ConnectivityStatus.unknown;
  Timer? _timer;
  bool _probing = false;
  DateTime? _lastProbeAt;

  ConnectivityStatus get status => _status;

  Stream<ConnectivityStatus> get changes => _controller.stream;

  void start() {
    if (_timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(probeInterval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Runs a probe immediately. Safe to call concurrently — overlapping calls
  /// are collapsed, and probes made less than two seconds apart are ignored.
  Future<ConnectivityStatus> check({bool force = false}) async {
    if (_probing) return _status;
    final DateTime now = DateTime.now();
    if (!force &&
        _lastProbeAt != null &&
        now.difference(_lastProbeAt!) < const Duration(seconds: 2)) {
      return _status;
    }

    _probing = true;
    _lastProbeAt = now;
    bool reachable = false;
    for (final String host in probeHosts) {
      try {
        final List<InternetAddress> result =
            await InternetAddress.lookup(host).timeout(probeTimeout);
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          reachable = true;
          break;
        }
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      }
    }
    _probing = false;

    final ConnectivityStatus next =
        reachable ? ConnectivityStatus.online : ConnectivityStatus.offline;
    if (next != _status) {
      _status = next;
      if (!_controller.isClosed) _controller.add(next);
    } else {
      _status = next;
    }
    return next;
  }

  void dispose() {
    stop();
    unawaited(_controller.close());
  }
}

/// Provides the singleton [ConnectivityService].
final Provider<ConnectivityService> connectivityServiceProvider =
    Provider<ConnectivityService>((Ref ref) {
  final ConnectivityService service = ConnectivityService()..start();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of connectivity changes, starting with the current value.
final StreamProvider<ConnectivityStatus> connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>((Ref ref) {
  final ConnectivityService service = ref.watch(connectivityServiceProvider);
  return service.changes;
}, initialValue: ConnectivityStatus.unknown);
