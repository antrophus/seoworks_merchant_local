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
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final clock = HlcClockService();
  await clock.init(db);
  db.hlcClock = clock;

  final driveService = GoogleDriveService();
  final connected = await driveService.trySilentSignIn();

  final engine = SyncEngine(db: db, driveService: driveService, clock: clock);
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
}
