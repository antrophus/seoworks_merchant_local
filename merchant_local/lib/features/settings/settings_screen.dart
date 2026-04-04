import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/api/poizon_client.dart';
import '../../core/providers.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/data_import_service.dart';
import '../../core/services/llm_router.dart';
import '../../core/services/sync_engine.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _appKeyCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  bool _isSaving = false;
  bool _obscureSecret = true;

  // 임포트 상태
  bool _isImporting = false;
  String? _importStatus;
  ImportResult? _importResult;

  @override
  void dispose() {
    _appKeyCtrl.dispose();
    _appSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_appKeyCtrl.text.isEmpty || _appSecretCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Key와 App Secret을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PoizonClient().configure(
        appKey: _appKeyCtrl.text.trim(),
        appSecret: _appSecretCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('POIZON API 설정이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _export(BuildContext ctx, String type) async {
    final db = ref.read(databaseProvider);
    final svc = DataExportService(db);
    try {
      switch (type) {
        case 'json':
          await svc.exportAllToJson();
        case 'sales_csv':
          await svc.exportSalesCsv();
        case 'inventory_csv':
          await svc.exportInventoryCsv();
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('내보내기 완료')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _startImport() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _startImportMobile();
    } else {
      await _startImportDesktop();
    }
  }

  /// Windows/macOS: 폴더 선택 → 직접 파일 접근
  Future<void> _startImportDesktop() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Supabase 백업 JSON 폴더 선택',
    );
    if (result == null) return;

    if (!mounted) return;
    final confirmed = await _confirmImport('선택한 폴더:\n$result');
    if (confirmed != true) return;

    _setImporting(true);
    final db = ref.read(databaseProvider);
    final importResult = await DataImportService(db).importFromBackupDir(
      result,
      onProgress: _onImportProgress,
    );
    _finishImport(importResult);
  }

  /// Android/iOS: 파일 선택 → 캐시로 복사 후 접근
  Future<void> _startImportMobile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '백업 JSON 파일 선택 (여러 개)',
      type: FileType.any,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    // 파일명 → 테이블명 매핑 (brands.json → brands)
    final fileMap = <String, String>{};
    for (final file in result.files) {
      if (file.path == null) continue;
      final name = p.basenameWithoutExtension(file.path!);
      fileMap[name] = file.path!;
    }

    if (fileMap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유효한 JSON 파일이 없습니다')),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmImport(
        '선택한 파일: ${fileMap.length}개\n${fileMap.keys.join(", ")}');
    if (confirmed != true) return;

    _setImporting(true);
    final db = ref.read(databaseProvider);
    final importResult = await DataImportService(db).importFromFiles(
      fileMap,
      onProgress: _onImportProgress,
    );
    _finishImport(importResult);
  }

  Future<bool?> _confirmImport(String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 임포트'),
        content: Text(
          '$content\n\n기존 데이터가 있으면 중복 건은 건너뜁니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('임포트 시작'),
          ),
        ],
      ),
    );
  }

  void _setImporting(bool v) {
    setState(() {
      _isImporting = v;
      _importStatus = v ? '임포트 준비 중...' : null;
      _importResult = null;
    });
  }

  void _onImportProgress(String tableName, int step, int total) {
    if (mounted) {
      setState(() {
        _importStatus = '$tableName 임포트 완료 ($step/$total)';
      });
    }
  }

  void _finishImport(ImportResult importResult) {
    if (mounted) {
      setState(() {
        _isImporting = false;
        _importResult = importResult;
        _importStatus = importResult.success ? '임포트 완료!' : '임포트 실패';
      });
      ref.invalidate(itemStatusCountsProvider);
      ref.invalidate(itemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // ── POIZON API 설정 ──────────────────────────
          Text(
            'POIZON Open API',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'open.poizon.com 에서 발급받은 App Key와 App Secret을 입력하세요.\n기기에 암호화되어 저장됩니다.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _appKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'App Key',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appSecretCtrl,
            obscureText: _obscureSecret,
            decoration: InputDecoration(
              labelText: 'App Secret',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSecret ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureSecret = !_obscureSecret),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ),
          const Divider(height: 48),

          // ── 데이터 내보내기 ──────────────────────────
          Text(
            '데이터 내보내기',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _export(context, 'json'),
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('전체 JSON'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _export(context, 'sales_csv'),
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('판매 CSV'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _export(context, 'inventory_csv'),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('재고 CSV'),
                ),
              ),
            ],
          ),
          const Divider(height: 48),

          // ── 데이터 임포트 ──────────────────────────
          Text(
            '데이터 임포트',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '기존 웹앱(Supabase)의 백업 JSON 폴더를 선택하여\n'
            '로컬 DB로 데이터를 가져옵니다.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isImporting ? null : _startImport,
              icon: _isImporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download),
              label: Text(_isImporting
                  ? '임포트 중...'
                  : (Platform.isAndroid || Platform.isIOS)
                      ? '백업 JSON 파일 선택 및 임포트'
                      : '백업 폴더 선택 및 임포트'),
            ),
          ),
          if (_importStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _importStatus!,
              style: TextStyle(
                color: _importResult?.success == false
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_importResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _importResult!.summary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ],
          const Divider(height: 48),

          // ── 데이터 정리 ──────────────────────────
          Text(
            '데이터 정리',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '중복 배송 이력 등 비정상 데이터를 정리합니다.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final count = await ref
                    .read(subRecordDaoProvider)
                    .cleanupDuplicateShipments();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(count > 0
                            ? '중복 배송 이력 $count건 삭제 완료'
                            : '정리할 중복 데이터가 없습니다')),
                  );
                }
              },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('중복 배송 이력 정리'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final engine = ref.read(syncEngineProvider);
                final count = await engine.reconcileStatusFromLogs();
                if (context.mounted) {
                  ref.invalidate(itemsProvider);
                  ref.invalidate(itemStatusCountsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(count > 0
                            ? '상태 보정 $count건 완료'
                            : '보정할 상태 불일치가 없습니다')),
                  );
                }
              },
              icon: const Icon(Icons.build_outlined),
              label: const Text('상태 보정 (status_logs 기준)'),
            ),
          ),
          const Divider(height: 48),

          // ── LLM API 키 (AI 이미지 인식) ──────────
          Text(
            'AI 이미지 인식 (LLM)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '상품 사진 AI 인식에 사용됩니다.\n캐스케이딩: Claude → Grok → DeepSeek (키가 있는 순서대로 시도)',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          const _LlmKeyField(
            provider: LlmProvider.claude,
            label: 'Claude (Anthropic)',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 10),
          const _LlmKeyField(
            provider: LlmProvider.grok,
            label: 'Grok (xAI)',
            icon: Icons.psychology,
          ),
          const SizedBox(height: 10),
          const _LlmKeyField(
            provider: LlmProvider.deepseek,
            label: 'DeepSeek',
            icon: Icons.smart_toy,
          ),
          const Divider(height: 48),

          // ── Google Drive 동기화 ──────────────────
          const _GoogleDriveSyncSection(),
        ],
      ),
    );
  }
}

/// LLM API 키 입력 필드 (개별 프로바이더)
class _LlmKeyField extends StatefulWidget {
  final LlmProvider provider;
  final String label;
  final IconData icon;

  const _LlmKeyField({
    required this.provider,
    required this.label,
    required this.icon,
  });

  @override
  State<_LlmKeyField> createState() => _LlmKeyFieldState();
}

class _LlmKeyFieldState extends State<_LlmKeyField> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _loaded = false;
  bool _hasKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await LlmRouter().getApiKey(widget.provider);
    if (mounted) {
      setState(() {
        _loaded = true;
        _hasKey = key != null && key.isNotEmpty;
        if (_hasKey) _ctrl.text = key!;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final value = _ctrl.text.trim();
      if (value.isEmpty) {
        await LlmRouter().removeApiKey(widget.provider);
      } else {
        await LlmRouter().setApiKey(widget.provider, value);
      }
      if (mounted) {
        setState(() => _hasKey = value.isNotEmpty);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.label} API 키 저장됨')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const LinearProgressIndicator();

    return Row(
      children: [
        Icon(widget.icon, size: 20, color: _hasKey ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  IconButton(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save, size: 18),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Google Drive 동기화 섹션 ──────────────────────────────────────────────────

class _GoogleDriveSyncSection extends ConsumerStatefulWidget {
  const _GoogleDriveSyncSection();

  @override
  ConsumerState<_GoogleDriveSyncSection> createState() =>
      _GoogleDriveSyncSectionState();
}

class _GoogleDriveSyncSectionState
    extends ConsumerState<_GoogleDriveSyncSection> {
  bool _isSyncing = false;
  bool _isSigningIn = false;
  String? _syncMessage;
  bool? _syncSuccess;

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final ok = await driveService.signIn();
      if (mounted) {
        if (ok) {
          // 로그인 성공 → 동기화 스케줄러 시작
          ref.read(syncSchedulerProvider).start();
          ref.read(syncEngineProvider).sync();
        }
        setState(() => _isSigningIn = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    ref.read(googleDriveServiceProvider).signOut();
    ref.read(syncSchedulerProvider).stop();
    setState(() {
      _syncMessage = null;
      _syncSuccess = null;
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
      _syncSuccess = null;
    });
    try {
      final result = await ref.read(syncEngineProvider).sync();
      if (mounted) {
        ref.invalidate(lastSyncAtProvider);
        ref.invalidate(itemsProvider);
        setState(() {
          _isSyncing = false;
          _syncSuccess = result.status == SyncStatus.success;
          _syncMessage = result.status == SyncStatus.success
              ? '동기화 완료  다운로드: ${result.tablesDownloaded}개 · 업로드: ${result.tablesUploaded}개'
              : '오류: ${result.errorMessage}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncSuccess = false;
          _syncMessage = '오류: $e';
        });
      }
    }
  }

  String _formatLastSync(DateTime? dt) {
    if (dt == null) return '동기화 이력 없음';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final driveService = ref.watch(googleDriveServiceProvider);
    final isConnected = driveService.isSignedIn;
    final lastSync = ref.watch(lastSyncAtProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google Drive 동기화',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),

        // ── 연결 상태 표시 ──
        Row(
          children: [
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isConnected
                    ? '${driveService.userEmail ?? "Google 계정"} 연결됨'
                    : '연결 안 됨',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
              ),
            ),
            if (isConnected)
              TextButton(
                onPressed: _signOut,
                child: const Text('로그아웃'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        lastSync.when(
          data: (dt) => Text(
            '마지막 동기화: ${_formatLastSync(dt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),

        if (!isConnected)
          // ── 로그인 버튼 ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSigningIn ? null : _signIn,
              icon: _isSigningIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login, size: 18),
              label: Text(_isSigningIn ? '로그인 중...' : 'Google 계정으로 로그인'),
            ),
          )
        else
          // ── 동기화 버튼 ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSyncing ? null : _syncNow,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync, size: 18),
              label: Text(_isSyncing ? '동기화 중...' : '지금 동기화'),
            ),
          ),

        if (_syncMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _syncMessage!,
            style: TextStyle(
              color: _syncSuccess == true ? Colors.green : Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
