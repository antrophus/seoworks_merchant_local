import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

final _pfBrandsProvider = FutureProvider<List<Brand>>((ref) {
  return ref.watch(masterDaoProvider).getAllBrands();
});

class ProductFormScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String productId;

  const ProductFormScreen({
    super.key,
    required this.itemId,
    required this.productId,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 상품 필드
  final _modelNameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  String? _selectedBrandId;
  String _modelCode = '';

  // 아이템(개별) 필드
  final _sizeKrCtrl = TextEditingController();
  final _sizeEuCtrl = TextEditingController();
  final _sizeUsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _modelNameCtrl.dispose();
    _categoryCtrl.dispose();
    _imageUrlCtrl.dispose();
    _sizeKrCtrl.dispose();
    _sizeEuCtrl.dispose();
    _sizeUsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loaded) return;
    _loaded = true;

    final product =
        await ref.read(masterDaoProvider).getProductById(widget.productId);
    final item = await ref.read(itemDaoProvider).getById(widget.itemId);

    if (!mounted) return;
    setState(() {
      if (product != null) {
        _modelCode = product.modelCode;
        _modelNameCtrl.text = product.modelName;
        _categoryCtrl.text = product.category ?? '';
        _imageUrlCtrl.text = product.imageUrl ?? '';
        _selectedBrandId = product.brandId;
      }
      if (item != null) {
        _sizeKrCtrl.text = item.sizeKr;
        _sizeEuCtrl.text = item.sizeEu ?? '';
        _sizeUsCtrl.text = item.sizeUs ?? '';
        _noteCtrl.text = item.note ?? '';
      }
    });
  }

  Future<void> _openBrandPicker(List<Brand> brands) async {
    final selected = await showModalBottomSheet<Brand>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BrandPickerSheet(
        brands: brands,
        selectedBrandId: _selectedBrandId,
      ),
    );
    if (selected != null) {
      setState(() => _selectedBrandId = selected.id);
    }
  }

  Future<void> _save(List<Brand> brands) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();

      // 상품 업데이트
      await ref.read(masterDaoProvider).upsertProduct(ProductsCompanion(
            id: Value(widget.productId),
            brandId: Value(_selectedBrandId),
            modelCode: Value(_modelCode),
            modelName: Value(_modelNameCtrl.text.trim()),
            category: Value(
                _categoryCtrl.text.trim().isNotEmpty
                    ? _categoryCtrl.text.trim()
                    : null),
            imageUrl: Value(
                _imageUrlCtrl.text.trim().isNotEmpty
                    ? _imageUrlCtrl.text.trim()
                    : null),
            createdAt: const Value.absent(),
          ));

      // 아이템 사이즈/비고 업데이트
      await ref.read(itemDaoProvider).updateItem(
            widget.itemId,
            ItemsCompanion(
              sizeKr: Value(_sizeKrCtrl.text.trim()),
              sizeEu: Value(_sizeEuCtrl.text.trim().isNotEmpty
                  ? _sizeEuCtrl.text.trim()
                  : null),
              sizeUs: Value(_sizeUsCtrl.text.trim().isNotEmpty
                  ? _sizeUsCtrl.text.trim()
                  : null),
              note: Value(_noteCtrl.text.trim().isNotEmpty
                  ? _noteCtrl.text.trim()
                  : null),
              updatedAt: Value(now),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정 완료')),
        );
        context.pop(true);
      }
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
    final brandsAsync = ref.watch(_pfBrandsProvider);

    return FutureBuilder(
      future: _loadData(),
      builder: (context, _) {
        return brandsAsync.when(
          data: (brands) => _buildForm(context, brands),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('오류: $e')),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, List<Brand> brands) {
    final selectedBrand = brands.cast<Brand?>()
        .firstWhere((b) => b?.id == _selectedBrandId, orElse: () => null);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 정보 수정'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () => _save(brands),
              child: const Text('저장',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 상품 정보 (공유) ──
            const _SectionHeader('상품 정보', subtitle: '같은 모델코드의 모든 재고에 반영됩니다'),
            const SizedBox(height: 12),

            // 모델코드 (읽기 전용)
            TextFormField(
              initialValue: _modelCode,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '모델코드',
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withAlpha(80),
                suffixIcon: const Tooltip(
                  message: '모델코드는 수정할 수 없습니다',
                  child: Icon(Icons.lock_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 모델명
            TextFormField(
              controller: _modelNameCtrl,
              decoration: const InputDecoration(
                labelText: '모델명',
                prefixIcon: Icon(Icons.text_fields),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '모델명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),

            // 브랜드 선택 (탭 → 검색 시트)
            InkWell(
              onTap: () => _openBrandPicker(brands),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '브랜드',
                  prefixIcon: Icon(Icons.label_important),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  selectedBrand?.name ?? '선택 안함',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedBrand != null
                        ? null
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 카테고리
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: '카테고리 (선택)',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
                hintText: '예: 스니커즈',
              ),
            ),
            const SizedBox(height: 12),

            // 이미지 URL
            TextFormField(
              controller: _imageUrlCtrl,
              decoration: const InputDecoration(
                labelText: '이미지 URL (선택)',
                prefixIcon: Icon(Icons.image_outlined),
                border: OutlineInputBorder(),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),

            // 이미지 미리보기
            if (_imageUrlCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrlCtrl.text,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 60,
                      color: Colors.grey.shade100,
                      child: const Center(
                          child: Text('이미지 로드 실패',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── 이 아이템 정보 (개별) ──
            const _SectionHeader('사이즈 정보', subtitle: '이 재고 아이템에만 반영됩니다'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sizeKrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'KR 사이즈',
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                      hintText: '270',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '필수' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sizeEuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'EU 사이즈 (선택)',
                      border: OutlineInputBorder(),
                      hintText: '42.5',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sizeUsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'US 사이즈 (선택)',
                      border: OutlineInputBorder(),
                      hintText: '9.5',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '비고 (선택)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _saving ? null : () => _save(brands),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('저장'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 헤더 ──

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade500)),
      ],
    );
  }
}

// ── 브랜드 검색 피커 시트 ──

class _BrandPickerSheet extends StatefulWidget {
  final List<Brand> brands;
  final String? selectedBrandId;

  const _BrandPickerSheet({required this.brands, this.selectedBrandId});

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<Brand> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.brands;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.brands
          : widget.brands
              .where((b) => b.name.toLowerCase().contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Text('브랜드 선택',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('선택 안함'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '브랜드 이름으로 검색',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                      : null,
                ),
                onChanged: _filter,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('검색 결과 없음',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final brand = _filtered[i];
                        final isSelected = brand.id == widget.selectedBrandId;
                        return ListTile(
                          title: Text(brand.name),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20)
                              : null,
                          selected: isSelected,
                          onTap: () => Navigator.pop(context, brand),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
