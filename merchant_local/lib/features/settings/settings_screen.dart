import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/poizon_client.dart';

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
          const SnackBar(content: Text('✅ POIZON API 설정이 저장되었습니다.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
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

          // ── Google Drive 동기화 (Phase 3에서 구현) ────
          Text(
            'Google Drive 동기화',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.cloud_off, color: Colors.grey),
            title: Text('아직 연결되지 않음'),
            subtitle: Text('Phase 3에서 구현 예정'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
