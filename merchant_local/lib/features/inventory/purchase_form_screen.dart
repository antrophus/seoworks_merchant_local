import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

/// 매입처 목록 Provider
final _sourcesProvider = FutureProvider<List<Source>>((ref) {
  return ref.watch(masterDaoProvider).getAllSources();
});

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String? purchaseId;

  const PurchaseFormScreen({
    super.key,
    required this.itemId,
    this.purchaseId,
  });

  bool get isEditing => purchaseId != null;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _dateController = TextEditingController();
  final _memoController = TextEditingController();

  String _paymentMethod = 'PERSONAL_CARD';
  String? _sourceId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isEditing) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _dateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || !widget.isEditing) return;
    _loaded = true;

    final purchase =
        await ref.read(purchaseDaoProvider).getByItemId(widget.itemId);
    if (purchase == null) return;

    if (purchase.purchasePrice != null) {
      _priceController.text =
          NumberFormat('#,###').format(purchase.purchasePrice);
    }
    _dateController.text = purchase.purchaseDate ?? '';
    _memoController.text = purchase.memo ?? '';
    _paymentMethod = purchase.paymentMethod;
    _sourceId = purchase.sourceId;
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dateController.text.isNotEmpty
        ? DateTime.tryParse(_dateController.text) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final price = int.tryParse(_priceController.text.replaceAll(',', ''));
      final entry = PurchasesCompanion(
        id: Value(widget.purchaseId ?? const Uuid().v4()),
        itemId: Value(widget.itemId),
        purchasePrice: Value(price),
        paymentMethod: Value(_paymentMethod),
        purchaseDate: Value(
            _dateController.text.isNotEmpty ? _dateController.text : null),
        sourceId: Value(_sourceId),
        memo: Value(
            _memoController.text.isNotEmpty ? _memoController.text : null),
        createdAt: Value(DateTime.now().toIso8601String()),
      );

      final dao = ref.read(purchaseDaoProvider);
      if (widget.isEditing) {
        await dao.updatePurchase(widget.purchaseId!, entry);
      } else {
        await dao.insertPurchase(entry);
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_loaded) {
      _loadExisting();
    }

    final sourcesAsync = ref.watch(_sourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '매입 수정' : '매입 등록'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 매입가
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '매입가 (원)',
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [_PriceInputFormatter()],
              validator: (v) {
                final raw = v?.replaceAll(',', '');
                return (raw == null || raw.isEmpty) ? '매입가를 입력하세요' : null;
              },
            ),
            const SizedBox(height: 16),

            // 결제수단
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: '결제수단',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CORPORATE_CARD', child: Text('법인카드')),
                DropdownMenuItem(value: 'PERSONAL_CARD', child: Text('개인카드')),
                DropdownMenuItem(value: 'CASH', child: Text('현금')),
                DropdownMenuItem(value: 'TRANSFER', child: Text('계좌이체')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),

            // 매입처
            sourcesAsync.when(
              data: (sources) {
                final validSourceId =
                    sources.any((s) => s.id == _sourceId) ? _sourceId : null;
                return DropdownButtonFormField<String?>(
                  initialValue: validSourceId,
                  decoration: const InputDecoration(
                    labelText: '매입처',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('선택 안함')),
                    ...sources.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _sourceId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // 매입일
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: '매입일',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _pickDate,
                ),
              ),
              readOnly: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // 메모
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // 부가세 환급 안내
            if (_paymentMethod == 'CORPORATE_CARD')
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '법인카드 결제 시 부가세 환급액이 자동 계산됩니다.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 저장 버튼
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.isEditing ? '수정' : '등록'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 매입가 자동 포맷팅 ──

class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(
          text: '', selection: const TextSelection.collapsed(offset: 0));
    }
    final formatted = NumberFormat('#,###').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
