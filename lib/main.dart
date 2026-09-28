import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Process entry point.
///
/// The app is offline-first, so bootstrap does the minimum possible work:
/// lock the orientation-independent system chrome and hand control to the
/// widget tree. Everything expensive (database, settings, first paint) is
/// resolved lazily through providers so a cold start never blocks on I/O.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: CvProApp()));
}
