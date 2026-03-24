import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

const _uuid = Uuid();

final _productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(masterDaoProvider).getAllProducts();
});

final _brandsProvider = FutureProvider<List<Brand>>((ref) {
  return ref.watch(masterDaoProvider).getAllBrands();
});

final _allSourcesProvider = FutureProvider<List<Source>>((ref) {
  return ref.watch(masterDaoProvider).getAllSources();
});

/// 사이즈-수량 행
class _SizeEntry {
  final sizeKrController = TextEditingController();
  final sizeEuController = TextEditingController();
  int qty = 1;

  String get sizeKr => sizeKrController.text.trim();
  String get sizeEu => sizeEuController.text.trim();

  void dispose() {
    sizeKrController.dispose();
    sizeEuController.dispose();
  }
}

class ItemRegisterScreen extends ConsumerStatefulWidget {
  final String? prefillBrand;
  final String? prefillModelCode;
  final String? prefillModelName;
  final String? prefillSizeKr;
  final String? prefillCategory;

  const ItemRegisterScreen({
    super.key,
    this.prefillBrand,
    this.prefillModelCode,
    this.prefillModelName,
    this.prefillSizeKr,
    this.prefillCategory,
  });

  bool get hasPrefill =>
      prefillBrand != null ||
      prefillModelCode != null ||
      prefillModelName != null ||
      prefillSizeKr != null ||
      prefillCategory != null;

  @override
  ConsumerState<ItemRegisterScreen> createState() => _ItemRegisterScreenState();
}

class _ItemRegisterScreenState extends ConsumerState<ItemRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── 입고 유형 ──
  String _entryType = 'OFFICE_STOCK';

  // ── 상품: 기존 선택 vs 신규 등록 ──
  bool _isNewProduct = false;
  Product? _selectedProduct;
  final _productSearchController = TextEditingController();
  List<Product> _filteredProducts = [];
  bool _showProductDropdown = false;

  // 신규 상품 필드
  final _modelCodeController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _selectedBrandId;

  // ── 사이즈 목록 (다건 입력) ──
  final List<_SizeEntry> _sizeEntries = [_SizeEntry()];

  // ── 사이즈차트 캐시 ──
  List<SizeChartData> _sizeCharts = [];
  String? _lastSizeChartBrand;

  // ── 공통 옵션 ──
  bool _isPersonal = false;
  final _noteController = TextEditingController();

  // ── 매입 정보 ──
  final _priceController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _purchaseMemoController = TextEditingController();
  String _paymentMethod = 'PERSONAL_CARD';
  String? _sourceId;

  bool _saving = false;
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _purchaseDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (widget.hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyPrefill());
    }
  }

  Future<void> _applyPrefill() async {
    if (_prefillApplied) return;
    _prefillApplied = true;

    // modelCode로 기존 상품 검색 시도
    if (widget.prefillModelCode != null) {
      final allProducts = await ref.read(_productsProvider.future);
      final code = widget.prefillModelCode!.toLowerCase();
      final match = allProducts.cast<Product?>().firstWhere(
            (p) => p!.modelCode.toLowerCase() == code,
            orElse: () => null,
          );

      if (match != null) {
        _selectProduct(match);
        // 사이즈 자동완성
        if (widget.prefillSizeKr != null) {
          _sizeEntries.first.sizeKrController.text = widget.prefillSizeKr!;
          _autoFillEuSize(_sizeEntries.first);
        }
        return;
      }
    }

    // 기존 상품 없음 → 신규 상품 등록 모드
    setState(() => _isNewProduct = true);

    if (widget.prefillModelCode != null) {
      _modelCodeController.text = widget.prefillModelCode!;
    }
    if (widget.prefillModelName != null) {
      _modelNameController.text = widget.prefillModelName!;
    }
    if (widget.prefillCategory != null) {
      _categoryController.text = widget.prefillCategory!;
    }

    // 브랜드명으로 DB 브랜드 매칭
    if (widget.prefillBrand != null) {
      final allBrands = await ref.read(_brandsProvider.future);
      final brandLower = widget.prefillBrand!.toLowerCase();
      final brandMatch = allBrands.cast<Brand?>().firstWhere(
            (b) => b!.name.toLowerCase() == brandLower,
            orElse: () => null,
          );
      if (brandMatch != null) {
        setState(() => _selectedBrandId = brandMatch.id);
        await _loadSizeCharts(brandMatch.name);
      }
    }

    // 사이즈 자동완성
    if (widget.prefillSizeKr != null) {
      _sizeEntries.first.sizeKrController.text = widget.prefillSizeKr!;
      _autoFillEuSize(_sizeEntries.first);
    }
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _modelCodeController.dispose();
    _modelNameController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    _purchaseDateController.dispose();
    _purchaseMemoController.dispose();
    for (final e in _sizeEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── 사이즈차트 로드 ──

  Future<void> _loadSizeCharts(String brandName) async {
    if (brandName == _lastSizeChartBrand) return;
    _lastSizeChartBrand = brandName;
    final charts = await ref
        .read(masterDaoProvider)
        .getSizeChartsByBrand(brandName);
    setState(() => _sizeCharts = charts);
  }

  void _autoFillEuSize(_SizeEntry entry) {
    if (_sizeCharts.isEmpty) return;
    final krText = entry.sizeKr;
    if (krText.isEmpty) return;
    final krNum = double.tryParse(krText);
    if (krNum == null) return;

    final match = _sizeCharts.cast<SizeChartData?>().firstWhere(
          (c) => c!.kr == krNum,
          orElse: () => null,
        );
    if (match?.eu != null) {
      entry.sizeEuController.text = match!.eu!;
    }
  }

  // ── 상품 검색 ──

  void _filterProducts(String query, List<Product> allProducts) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = [];
        _showProductDropdown = false;
      });
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredProducts = allProducts
          .where((p) =>
              p.modelCode.toLowerCase().contains(lower) ||
              p.modelName.toLowerCase().contains(lower))
          .take(10)
          .toList();
      _showProductDropdown = _filteredProducts.isNotEmpty;
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _productSearchController.text =
          '${product.modelName} (${product.modelCode})';
      _showProductDropdown = false;
    });

    // 브랜드 기반 사이즈차트 로드
    if (product.brandId != null) {
      ref.read(masterDaoProvider).getBrandById(product.brandId!).then((brand) {
        if (brand != null) _loadSizeCharts(brand.name);
      });
    }
  }

  void _clearProduct() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
      _showProductDropdown = false;
      _sizeCharts = [];
      _lastSizeChartBrand = null;
    });
  }

  // ── 사이즈 행 관리 ──

  void _addSizeEntry() {
    setState(() => _sizeEntries.add(_SizeEntry()));
  }

  void _removeSizeEntry(int index) {
    if (_sizeEntries.length <= 1) return;
    setState(() {
      _sizeEntries[index].dispose();
      _sizeEntries.removeAt(index);
    });
  }

  int get _totalItemCount =>
      _sizeEntries.fold<int>(0, (sum, e) => sum + e.qty);

  // ── 날짜 ──

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _purchaseDateController.text.isNotEmpty
        ? DateTime.tryParse(_purchaseDateController.text) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // ── SKU 생성 ──

  Future<String> _generateSku(String modelCode, String sizeKr, int seq) async {
    final base = '$modelCode-$sizeKr';
    final productId = _isNewProduct ? null : _selectedProduct?.id;
    int existingCount = 0;
    if (productId != null) {
      final existingItems =
          await ref.read(itemDaoProvider).getByProductId(productId);
      existingCount =
          existingItems.where((item) => item.sku.startsWith(base)).length;
    }
    final seqNum = (existingCount + seq).toString().padLeft(3, '0');
    return '$base-$seqNum';
  }

  // ── 매입처 추가 다이얼로그 ──

  Future<void> _showAddSourceDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final sourceType = _entryType == 'ORDER_PLACED' ? 'online' : 'offline';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${sourceType == 'online' ? '온라인' : '오프라인'} 매입처 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '매입처명',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            if (sourceType == 'online') ...[
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL (선택)',
                  border: OutlineInputBorder(),
                  hintText: 'https://...',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final id = _uuid.v4();
              await ref.read(masterDaoProvider).upsertSource(SourcesCompanion(
                    id: Value(id),
                    name: Value(nameCtrl.text.trim()),
                    type: Value(sourceType),
                    url: Value(urlCtrl.text.isNotEmpty ? urlCtrl.text.trim() : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ));
              if (ctx.mounted) Navigator.pop(ctx, true);
              // 선택
              setState(() => _sourceId = id);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Provider 새로고침
      ref.invalidate(_allSourcesProvider);
    }

    nameCtrl.dispose();
    urlCtrl.dispose();
  }

  // ── 저장 ──

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isNewProduct && _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상품을 선택하세요')),
      );
      return;
    }

    for (int i = 0; i < _sizeEntries.length; i++) {
      if (_sizeEntries[i].sizeKr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}번째 사이즈를 입력하세요')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();

      // ── 1) 상품 확보 ──
      String productId;
      String modelCode;

      if (_isNewProduct) {
        productId = _uuid.v4();
        modelCode = _modelCodeController.text.trim();
        final productEntry = ProductsCompanion(
          id: Value(productId),
          brandId: Value(_selectedBrandId),
          modelCode: Value(modelCode),
          modelName: Value(_modelNameController.text.trim()),
          category: Value(_categoryController.text.isNotEmpty
              ? _categoryController.text.trim()
              : null),
          createdAt: Value(now),
        );
        await ref.read(masterDaoProvider).upsertProduct(productEntry);
      } else {
        productId = _selectedProduct!.id;
        modelCode = _selectedProduct!.modelCode;
      }

      // ── 2) 사이즈별 Item + Purchase 생성 ──
      final price = int.tryParse(_priceController.text.replaceAll(',', ''));
      int createdCount = 0;

      for (final sizeEntry in _sizeEntries) {
        for (int q = 0; q < sizeEntry.qty; q++) {
          createdCount++;
          final itemId = _uuid.v4();
          final purchaseId = _uuid.v4();

          final sku = await _generateSku(
              modelCode, sizeEntry.sizeKr, q + 1);

          await ref.read(itemDaoProvider).insertItem(ItemsCompanion(
                id: Value(itemId),
                productId: Value(productId),
                sku: Value(sku),
                sizeKr: Value(sizeEntry.sizeKr),
                sizeEu: Value(
                    sizeEntry.sizeEu.isNotEmpty ? sizeEntry.sizeEu : null),
                isPersonal: Value(_isPersonal),
                currentStatus: Value(_entryType),
                note: Value(_noteController.text.isNotEmpty
                    ? _noteController.text
                    : null),
                createdAt: Value(now),
                updatedAt: Value(now),
              ));

          await ref.read(purchaseDaoProvider).insertPurchase(PurchasesCompanion(
                id: Value(purchaseId),
                itemId: Value(itemId),
                purchasePrice: Value(price),
                paymentMethod: Value(_paymentMethod),
                purchaseDate: Value(_purchaseDateController.text.isNotEmpty
                    ? _purchaseDateController.text
                    : null),
                sourceId: Value(_sourceId),
                memo: Value(_purchaseMemoController.text.isNotEmpty
                    ? _purchaseMemoController.text
                    : null),
                createdAt: Value(now),
              ));

          await ref
              .read(itemDaoProvider)
              .updateStatus(itemId, _entryType, note: '입고 등록');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$createdCount건 입고 등록 완료')),
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

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_productsProvider);
    final brandsAsync = ref.watch(_brandsProvider);
    final sourcesAsync = ref.watch(_allSourcesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('입고 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 입고 유형 ──
            _sectionTitle(theme, '입고 유형'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'OFFICE_STOCK',
                  label: Text('오프라인 입고'),
                  icon: Icon(Icons.warehouse),
                ),
                ButtonSegment(
                  value: 'ORDER_PLACED',
                  label: Text('온라인 주문'),
                  icon: Icon(Icons.shopping_cart),
                ),
              ],
              selected: {_entryType},
              onSelectionChanged: (v) {
                setState(() {
                  _entryType = v.first;
                  _sourceId = null; // 입고 유형 변경 시 매입처 초기화
                });
              },
            ),
            const SizedBox(height: 24),

            // ── 상품 정보 ──
            Row(
              children: [
                Expanded(child: _sectionTitle(theme, '상품 정보')),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isNewProduct = !_isNewProduct;
                      _selectedProduct = null;
                      _productSearchController.clear();
                      _showProductDropdown = false;
                    });
                  },
                  icon: Icon(
                      _isNewProduct ? Icons.search : Icons.add_circle_outline,
                      size: 18),
                  label: Text(_isNewProduct ? '기존 상품 검색' : '신규 상품 등록',
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_isNewProduct) _buildProductSearch(productsAsync),
            if (_isNewProduct) _buildNewProductForm(brandsAsync),
            const SizedBox(height: 24),

            // ── 사이즈·수량 ──
            Row(
              children: [
                Expanded(child: _sectionTitle(theme, '사이즈 · 수량')),
                Text('총 $_totalItemCount족',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildSizeEntries(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addSizeEntry,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('사이즈 추가'),
              ),
            ),
            const SizedBox(height: 8),

            // 개인용
            SwitchListTile(
              title: const Text('개인용'),
              subtitle: const Text('개인 소장용 상품'),
              value: _isPersonal,
              onChanged: (v) => setState(() => _isPersonal = v),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),

            // ── 매입 정보 ──
            _sectionTitle(theme, '매입 정보'),
            const SizedBox(height: 8),
            _buildPurchaseFields(sourcesAsync),
            const SizedBox(height: 24),

            // ── 저장 버튼 ──
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_box),
              label: Text('입고 등록 ($_totalItemCount건)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── 섹션 타이틀 ──

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(text,
        style: theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.bold));
  }

  // ── 기존 상품 검색 ──

  Widget _buildProductSearch(AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      data: (allProducts) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _productSearchController,
              decoration: InputDecoration(
                labelText: '상품 검색 (모델명/모델코드)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _selectedProduct != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearProduct,
                      )
                    : null,
              ),
              onChanged: (v) => _filterProducts(v, allProducts),
              validator: (_) =>
                  _selectedProduct == null && !_isNewProduct
                      ? '상품을 선택하세요'
                      : null,
            ),
            if (_showProductDropdown)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, i) {
                    final p = _filteredProducts[i];
                    return ListTile(
                      dense: true,
                      leading: p.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                p.imageUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.inventory_2, size: 24),
                              ),
                            )
                          : const Icon(Icons.inventory_2, size: 24),
                      title:
                          Text(p.modelName, style: const TextStyle(fontSize: 13)),
                      subtitle:
                          Text(p.modelCode, style: const TextStyle(fontSize: 11)),
                      onTap: () => _selectProduct(p),
                    );
                  },
                ),
              ),
            if (_selectedProduct != null) _buildSelectedProductCard(),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('상품 로드 실패: $e'),
    );
  }

  Widget _buildSelectedProductCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (_selectedProduct!.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _selectedProduct!.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 44, height: 44),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedProduct!.modelName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(_selectedProduct!.modelCode,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── 신규 상품 등록 폼 ──

  Widget _buildNewProductForm(AsyncValue<List<Brand>> brandsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 브랜드 선택
        brandsAsync.when(
          data: (brands) {
            // value가 items에 없으면 null로 폴백
            final validBrandId = brands.any((b) => b.id == _selectedBrandId)
                ? _selectedBrandId
                : null;
            return DropdownButtonFormField<String?>(
              value: validBrandId,
              decoration: const InputDecoration(
                labelText: '브랜드',
                prefixIcon: Icon(Icons.label_important),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('선택 안함')),
                ...brands.map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name),
                    )),
              ],
              onChanged: (v) {
                setState(() => _selectedBrandId = v);
                // 브랜드 변경 시 사이즈차트 로드
                if (v != null) {
                  final brand = brands.firstWhere((b) => b.id == v);
                  _loadSizeCharts(brand.name);
                } else {
                  setState(() {
                    _sizeCharts = [];
                    _lastSizeChartBrand = null;
                  });
                }
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('브랜드 로드 실패'),
        ),
        const SizedBox(height: 12),

        // 모델코드
        TextFormField(
          controller: _modelCodeController,
          decoration: const InputDecoration(
            labelText: '모델코드',
            prefixIcon: Icon(Icons.tag),
            border: OutlineInputBorder(),
            hintText: '예: DZ5485-612',
          ),
          validator: (v) =>
              _isNewProduct && (v == null || v.trim().isEmpty)
                  ? '모델코드를 입력하세요'
                  : null,
        ),
        const SizedBox(height: 12),

        // 모델명
        TextFormField(
          controller: _modelNameController,
          decoration: const InputDecoration(
            labelText: '모델명',
            prefixIcon: Icon(Icons.text_fields),
            border: OutlineInputBorder(),
            hintText: '예: Nike Dunk Low Retro',
          ),
          validator: (v) =>
              _isNewProduct && (v == null || v.trim().isEmpty)
                  ? '모델명을 입력하세요'
                  : null,
        ),
        const SizedBox(height: 12),

        // 카테고리
        TextFormField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: '카테고리 (선택)',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
            hintText: '예: 스니커즈',
          ),
        ),
      ],
    );
  }

  // ── 사이즈 · 수량 행 목록 ──

  List<Widget> _buildSizeEntries() {
    return List.generate(_sizeEntries.length, (i) {
      final entry = _sizeEntries[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 번호
            SizedBox(
              width: 20,
              child: Text('${i + 1}',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 4),

            // 사이즈 KR
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: entry.sizeKrController,
                decoration: const InputDecoration(
                  labelText: 'KR',
                  border: OutlineInputBorder(),
                  hintText: '270',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  errorStyle: TextStyle(fontSize: 10),
                ),
                onChanged: (_) => _autoFillEuSize(entry),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '필수' : null,
              ),
            ),
            const SizedBox(width: 8),

            // 사이즈 EU (선택)
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: entry.sizeEuController,
                decoration: const InputDecoration(
                  labelText: 'EU',
                  border: OutlineInputBorder(),
                  hintText: '42.5',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 수량 스테퍼: - [qty] +
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: entry.qty > 1
                      ? () => setState(() => entry.qty--)
                      : null,
                ),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text('${entry.qty}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                _StepperButton(
                  icon: Icons.add,
                  onTap: () => setState(() => entry.qty++),
                ),
              ],
            ),

            // 삭제 버튼
            SizedBox(
              width: 32,
              child: _sizeEntries.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      onPressed: () => _removeSizeEntry(i),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    });
  }

  // ── 매입 정보 필드 ──

  Widget _buildPurchaseFields(AsyncValue<List<Source>> sourcesAsync) {
    return Column(
      children: [
        // 매입가
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: '매입가 (원) — 족당 단가',
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
          value: _paymentMethod,
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

        // 매입처 (입고 유형에 따라 필터)
        sourcesAsync.when(
          data: (allSources) {
            final filterType =
                _entryType == 'ORDER_PLACED' ? 'online' : 'offline';
            final filtered =
                allSources.where((s) => s.type == filterType).toList();

            // 현재 선택된 sourceId가 필터된 목록에 없으면 초기화
            final validSourceId =
                filtered.any((s) => s.id == _sourceId) ? _sourceId : null;
            if (validSourceId != _sourceId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _sourceId = validSourceId);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  value: validSourceId,
                  decoration: InputDecoration(
                    labelText:
                        '매입처 (${filterType == 'online' ? '온라인' : '오프라인'})',
                    prefixIcon: const Icon(Icons.store),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('선택 안함')),
                    ...filtered.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                    // 구분선 + 새 매입처 추가
                    const DropdownMenuItem(
                      value: '__add_new__',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('새 매입처 추가',
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '__add_new__') {
                      _showAddSourceDialog();
                      return;
                    }
                    setState(() => _sourceId = v);
                  },
                ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // 매입일
        TextFormField(
          controller: _purchaseDateController,
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

        // 비고
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: '비고 (선택)',
            prefixIcon: Icon(Icons.note),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),

        // 법인카드 안내
        if (_paymentMethod == 'CORPORATE_CARD') ...[
          const SizedBox(height: 12),
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
                          color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 수량 스테퍼 버튼 ──

// ── 매입가 자동 포맷팅 (123000 → 123,000) ──

class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }
    final formatted = NumberFormat('#,###').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
              color: enabled ? Colors.grey.shade400 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
    );
  }
}
