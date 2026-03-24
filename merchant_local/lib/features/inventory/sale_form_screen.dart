import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

const _platforms = ['POIZON', 'KREAM', 'SOLDOUT', 'DIRECT', 'OTHER'];

const _platformLabels = <String, String>{
  'POIZON': 'POIZON (득물)',
  'KREAM': 'KREAM',
  'SOLDOUT': 'SOLDOUT',
  'DIRECT': '직거래',
  'OTHER': '기타',
};

class SaleFormScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String? saleId; // null이면 등록, 있으면 수정

  const SaleFormScreen({
    super.key,
    required this.itemId,
    this.saleId,
  });

  bool get isEditing => saleId != null;

  @override
  ConsumerState<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends ConsumerState<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listedPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _feeRateController = TextEditingController();
  final _dateController = TextEditingController();
  final _settledAtController = TextEditingController();
  final _memoController = TextEditingController();

  String _platform = 'POIZON';
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
    _listedPriceController.dispose();
    _sellPriceController.dispose();
    _feeRateController.dispose();
    _dateController.dispose();
    _settledAtController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || !widget.isEditing) return;
    _loaded = true;

    final sale = await ref.read(saleDaoProvider).getByItemId(widget.itemId);
    if (sale == null) return;

    _platform = sale.platform;
    _listedPriceController.text =
        sale.listedPrice != null ? '${sale.listedPrice}' : '';
    _sellPriceController.text =
        sale.sellPrice != null ? '${sale.sellPrice}' : '';
    _feeRateController.text = sale.platformFeeRate != null
        ? (sale.platformFeeRate! * 100).toStringAsFixed(1)
        : '';
    _dateController.text = sale.saleDate ?? '';
    _settledAtController.text = sale.settledAt ?? '';
    _memoController.text = sale.memo ?? '';
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

  Future<void> _pickSettledAt() async {
    final now = DateTime.now();
    final initial = _settledAtController.text.isNotEmpty
        ? DateTime.tryParse(_settledAtController.text) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _settledAtController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  bool get _showFeeRateField =>
      _platform != 'POIZON' && _platform != 'DIRECT' && _platform != 'OTHER';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final listedPrice = int.tryParse(_listedPriceController.text);
      final sellPrice = int.tryParse(_sellPriceController.text);
      final feeRatePercent = double.tryParse(_feeRateController.text);
      final feeRate =
          feeRatePercent != null ? feeRatePercent / 100.0 : null;

      final entry = SalesCompanion(
        id: Value(widget.saleId ?? const Uuid().v4()),
        itemId: Value(widget.itemId),
        platform: Value(_platform),
        listedPrice: Value(listedPrice),
        sellPrice: Value(sellPrice),
        platformFeeRate: Value(feeRate),
        saleDate: Value(
            _dateController.text.isNotEmpty ? _dateController.text : null),
        settledAt: Value(
            _settledAtController.text.isNotEmpty ? _settledAtController.text : null),
        memo: Value(
            _memoController.text.isNotEmpty ? _memoController.text : null),
        dataSource: const Value('manual'),
        createdAt: Value(DateTime.now().toIso8601String()),
      );

      final dao = ref.read(saleDaoProvider);
      if (widget.isEditing) {
        await dao.updateSale(widget.saleId!, entry);
      } else {
        await dao.insertSale(entry);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '판매 수정' : '판매 등록'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 플랫폼
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: const InputDecoration(
                labelText: '판매 플랫폼',
                prefixIcon: Icon(Icons.storefront),
                border: OutlineInputBorder(),
              ),
              items: _platforms
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_platformLabels[p] ?? p),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: 16),

            // 등록가
            TextFormField(
              controller: _listedPriceController,
              decoration: const InputDecoration(
                labelText: '등록가 (원)',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // 판매가
            TextFormField(
              controller: _sellPriceController,
              decoration: const InputDecoration(
                labelText: '판매가 (원)',
                prefixIcon: Icon(Icons.sell),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.isEmpty) ? '판매가를 입력하세요' : null,
            ),
            const SizedBox(height: 16),

            // 수수료율 (KREAM, SOLDOUT 등)
            if (_showFeeRateField) ...[
              TextFormField(
                controller: _feeRateController,
                decoration: const InputDecoration(
                  labelText: '수수료율 (%)',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  hintText: '예: 5.5',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
            ],

            // POIZON 수수료 안내
            if (_platform == 'POIZON')
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'POIZON 수수료는 카테고리별 규칙에 따라 자동 계산됩니다.',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_platform == 'DIRECT' || _platform == 'OTHER')
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '직거래/기타는 수수료가 없습니다.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 판매일
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: '판매일',
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

            // 정산일
            TextFormField(
              controller: _settledAtController,
              decoration: InputDecoration(
                labelText: '정산일',
                prefixIcon: const Icon(Icons.payments),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_settledAtController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () =>
                            setState(() => _settledAtController.clear()),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _pickSettledAt,
                    ),
                  ],
                ),
              ),
              readOnly: true,
              onTap: _pickSettledAt,
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
