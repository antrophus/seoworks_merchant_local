import 'package:crdt/crdt.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class HlcClockService {
  late Hlc _canonicalTime;
  late String _nodeId;

  String get nodeId => _nodeId;
  Hlc get canonicalTime => _canonicalTime;

  /// SyncMeta에서 device_id를 읽어 초기화. 없으면 새로 생성.
  Future<void> init(AppDatabase db) async {
    final meta = await (db.select(db.syncMeta)
          ..where((t) => t.key.equals('device_id')))
        .getSingleOrNull();

    if (meta != null) {
      _nodeId = meta.value;
    } else {
      _nodeId = const Uuid().v4();
      await db.into(db.syncMeta).insert(SyncMetaCompanion.insert(
            key: 'device_id',
            value: _nodeId,
            updatedAt: DateTime.now(),
          ));
    }

    _canonicalTime = Hlc.now(_nodeId);
  }

  /// 로컬 쓰기 시 호출 — 단조 증가하는 HLC 반환
  Hlc increment() {
    _canonicalTime = _canonicalTime.increment();
    return _canonicalTime;
  }

  /// 리모트 HLC 수신 시 호출 — 시계 동기화
  void merge(Hlc remote) {
    _canonicalTime = _canonicalTime.merge(remote);
  }
}
