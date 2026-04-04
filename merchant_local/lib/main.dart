import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/services/hlc_clock_service.dart';
import 'core/services/google_drive_service.dart';
import 'core/services/sync_engine.dart';
import 'core/services/sync_scheduler.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter 프레임워크 에러 핸들러
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
    };

    // 플랫폼 비동기 에러 핸들러 (토큰 갱신 실패 등)
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformError] $error\n$stack');
      return true; // 처리 완료 — 앱 종료 방지
    };

    final db = AppDatabase();
    final clock = HlcClockService();
    await clock.init(db);
    db.hlcClock = clock;

    final driveService = GoogleDriveService();
    final connected = await driveService.trySilentSignIn();

    final engine =
        SyncEngine(db: db, driveService: driveService, clock: clock);
    final scheduler = SyncScheduler(engine);

    if (connected) {
      scheduler.start();
      engine.sync();
    }

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hlcClockProvider.overrideWithValue(clock),
          googleDriveServiceProvider.overrideWithValue(driveService),
          syncEngineProvider.overrideWithValue(engine),
          syncSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MerchantApp(),
      ),
    );
  }, (error, stack) {
    // Zone 미처리 에러 — 로그만 남기고 앱 유지
    debugPrint('[UncaughtError] $error\n$stack');
  });
}
