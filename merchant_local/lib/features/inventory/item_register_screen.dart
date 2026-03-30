import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'widgets/size_picker_sheet.dart';

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

/// 최근 선택한 브랜드 ID 목록 (최대 5개, 앱 세션 내 유지)
final _recentBrandIdsProvider = StateProvider<List<String>>((ref) => []);

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
  final _modelCodeFocusNode = FocusNode();
  final _modelNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
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
  String _paymentMethod = 'CORPORATE_CARD';
  String? _sourceId;

  bool _saving = false;
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _purchaseDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _modelCodeFocusNode.addListener(_onModelCodeFocusChanged);
    if (widget.hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyPrefill());
    }
  }

  // ── 신규→기존 전이: 모델코드 포커스 해제 시 DB 조회 ──
  void _onModelCodeFocusChanged() {
    if (!_modelCodeFocusNode.hasFocus) _checkModelCodeExists();
  }

  Future<void> _checkModelCodeExists() async {
    final code = _modelCodeController.text.trim();
    if (code.isEmpty || !_isNewProduct) return;

    final existing =
        await ref.read(masterDaoProvider).getProductByModelCode(code);
    if (existing != null && mounted) {
      await _selectProduct(existing);
      if (!mounted) return;
      setState(() => _isNewProduct = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 등록된 상품입니다. 기존 상품으로 자동 전환됨: ${existing.modelName}'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  // ── 기존→신규 전이: 검색어로 신규 폼 전환 ──
  void _switchToNewWithQuery(String query) {
    setState(() {
      _isNewProduct = true;
      _selectedProduct = null;
      _productSearchController.clear();
      _showProductDropdown = false;
      // 검색어가 모델코드 형태(영문+숫자+하이픈)면 모델코드에, 아니면 모델명에 채움
      final looksLikeCode = RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(query);
      if (looksLikeCode) {
        _modelCodeController.text = query;
      } else {
        _modelNameController.text = query;
      }
    });
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
        await _selectProduct(match);
        // 사이즈 자동완성 (사이즈차트 로드 완료 후)
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
    _modelCodeFocusNode.removeListener(_onModelCodeFocusChanged);
    _modelCodeFocusNode.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
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
    if (brandName == _lastSizeChartBrand && _sizeCharts.isNotEmpty) return;
    _lastSizeChartBrand = brandName;
    final charts =
        await ref.read(masterDaoProvider).getSizeChartsByBrand(brandName);
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

  Future<void> _selectProduct(Product product) async {
    setState(() {
      _selectedProduct = product;
      _productSearchController.text =
          '${product.modelName} (${product.modelCode})';
      _showProductDropdown = false;
    });

    // 브랜드 기반 사이즈차트 로드
    if (product.brandId != null) {
      final brand =
          await ref.read(masterDaoProvider).getBrandById(product.brandId!);
      if (brand != null) await _loadSizeCharts(brand.name);
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

  Future<void> _openSizePicker(_SizeEntry entry) async {
    final brandName = _lastSizeChartBrand;
    if (brandName == null) return;
    final category = _selectedProduct?.category;
    final result = await showSizePickerSheet(
      context: context,
      ref: ref,
      brandName: brandName,
      category: category,
    );
    if (result != null) {
      setState(() {
        entry.sizeKrController.text = result.kr;
        if (result.eu != null) entry.sizeEuController.text = result.eu!;
      });
    }
  }

  int get _totalItemCount => _sizeEntries.fold<int>(0, (sum, e) => sum + e.qty);

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

  // ── 브랜드 선택 ──

  void _onBrandSelected(Brand brand) {
    setState(() => _selectedBrandId = brand.id);
    _loadSizeCharts(brand.name);
    // 최근 브랜드 업데이트 (최대 5개, 중복 제거 후 맨 앞 삽입)
    final recent = [...ref.read(_recentBrandIdsProvider)];
    recent.remove(brand.id);
    recent.insert(0, brand.id);
    if (recent.length > 5) recent.removeLast();
    ref.read(_recentBrandIdsProvider.notifier).state = recent;
  }

  Future<void> _openBrandPicker(List<Brand> brands) async {
    final selected = await showModalBottomSheet<Brand>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BrandPickerSheet(
        brands: brands,
        recentBrandIds: ref.read(_recentBrandIdsProvider),
        selectedBrandId: _selectedBrandId,
      ),
    );
    if (selected != null) _onBrandSelected(selected);
  }

  // ── 매입처 추가 다이얼로그 ──

  Future<void> _showAddSourceDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final sourceType = _entryType == 'ORDER_PLACED' ? 'online' : 'offline';

    // showDialog<String?>: 새로 생성된 sourceId를 반환값으로 전달
    // setState는 dialog가 완전히 닫힌 후 호출해야 함
    // (dialog callback 내부에서 호출하면 InheritedWidget 정리 도중 rebuild 충돌)
    final newSourceId = await showDialog<String?>(
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
            onPressed: () => Navigator.pop(ctx),
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
                    url: Value(
                        urlCtrl.text.isNotEmpty ? urlCtrl.text.trim() : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ));
              // id를 반환값으로 전달 — setState는 dialog 완전 종료 후 호출
              if (ctx.mounted) Navigator.pop(ctx, id);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    urlCtrl.dispose();

    if (newSourceId != null) {
      ref.invalidate(_allSourcesProvider);
      // dialog가 완전히 닫힌 후 setState 호출 → assertion 에러 방지
      setState(() => _sourceId = newSourceId);
    }
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
        modelCode = _modelCodeController.text.trim();

        // 동일 model_code 상품이 이미 존재하면 해당 id 재사용
        // (새 uuid로 INSERT하면 model_code UNIQUE 제약 위반 발생)
        final existing =
            await ref.read(masterDaoProvider).getProductByModelCode(modelCode);
        if (existing != null) {
          productId = existing.id;
        } else {
          productId = _uuid.v4();
          final productEntry = ProductsCompanion(
            id: Value(productId),
            brandId: Value(_selectedBrandId),
            modelCode: Value(modelCode),
            modelName: Value(_modelNameController.text.trim()),
            category: Value(_categoryController.text.isNotEmpty
                ? _categoryController.text.trim()
                : null),
            imageUrl: Value(_imageUrlController.text.trim().isNotEmpty
                ? _imageUrlController.text.trim()
                : null),
            createdAt: Value(now),
          );
          await ref.read(masterDaoProvider).upsertProduct(productEntry);
        }
      } else {
        productId = _selectedProduct!.id;
        modelCode = _selectedProduct!.modelCode;
      }

      // ── 2) 사이즈별 Item + Purchase 생성 ──
      final price = int.tryParse(_priceController.text.replaceAll(',', ''));

      // SKU는 트랜잭션 밖에서 미리 생성 (DB 조회 필요)
      final rowData =
          <({String itemId, String purchaseId, String sku, _SizeEntry entry})>[];
      for (final sizeEntry in _sizeEntries) {
        for (int q = 0; q < sizeEntry.qty; q++) {
          final itemId = _uuid.v4();
          final purchaseId = _uuid.v4();
          final sku = await _generateSku(modelCode, sizeEntry.sizeKr, q + 1);
          rowData.add(
              (itemId: itemId, purchaseId: purchaseId, sku: sku, entry: sizeEntry));
        }
      }

      // 모든 INSERT를 단일 트랜잭션으로 묶음
      // → Drift stream이 커밋 후 1회만 emit
      // → loadBatchData 실행 시 모든 purchase가 이미 DB에 존재 (매입일 미상 버그 방지)
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        for (final row in rowData) {
          await ref.read(itemDaoProvider).insertItem(ItemsCompanion(
                id: Value(row.itemId),
                productId: Value(productId),
                sku: Value(row.sku),
                sizeKr: Value(row.entry.sizeKr),
                sizeEu: Value(
                    row.entry.sizeEu.isNotEmpty ? row.entry.sizeEu : null),
                isPersonal: Value(_isPersonal),
                currentStatus: Value(_entryType),
                note: Value(_noteController.text.isNotEmpty
                    ? _noteController.text
                    : null),
                createdAt: Value(now),
                updatedAt: Value(now),
              ));

          await ref.read(purchaseDaoProvider).insertPurchase(PurchasesCompanion(
                id: Value(row.purchaseId),
                itemId: Value(row.itemId),
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
        }
      });

      final createdCount = rowData.length;

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
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold));
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
              validator: (_) => _selectedProduct == null && !_isNewProduct
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
                      title: Text(p.modelName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(p.modelCode,
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => _selectProduct(p),
                    );
                  },
                ),
              ),
            // 검색어 있으나 결과 없음 → 신규 등록 전환 유도
            if (_productSearchController.text.isNotEmpty &&
                _filteredProducts.isEmpty &&
                _selectedProduct == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _switchToNewWithQuery(_productSearchController.text.trim()),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(
                      '"${_productSearchController.text.trim()}" 신규 상품으로 등록'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
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
        // 브랜드 선택 (검색 + 최근 선택 핀)
        brandsAsync.when(
          data: (brands) {
            final recentIds = ref.watch(_recentBrandIdsProvider);
            final recentBrands = recentIds
                .map((id) => brands.cast<Brand?>()
                    .firstWhere((b) => b?.id == id, orElse: () => null))
                .whereType<Brand>()
                .toList();

            final selectedBrand = brands.cast<Brand?>()
                .firstWhere((b) => b?.id == _selectedBrandId,
                    orElse: () => null);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 최근 선택 브랜드 빠른 선택 칩
                if (recentBrands.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.history,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('최근 브랜드',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: recentBrands.map((brand) {
                        final isSelected = brand.id == _selectedBrandId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(brand.name,
                                style: const TextStyle(fontSize: 13)),
                            selected: isSelected,
                            onSelected: (_) => _onBrandSelected(brand),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // 브랜드 선택 필드 (탭 → 검색 시트)
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
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('브랜드 로드 실패'),
        ),
        const SizedBox(height: 12),

        // 모델코드 — 포커스 해제 시 기존 상품 여부 자동 체크
        TextFormField(
          controller: _modelCodeController,
          focusNode: _modelCodeFocusNode,
          decoration: const InputDecoration(
            labelText: '모델코드',
            prefixIcon: Icon(Icons.tag),
            border: OutlineInputBorder(),
            hintText: '예: DZ5485-612',
          ),
          validator: (v) => _isNewProduct && (v == null || v.trim().isEmpty)
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
          validator: (v) => _isNewProduct && (v == null || v.trim().isEmpty)
              ? '모델명을 입력하세요'
              : null,
        ),
        const SizedBox(height: 12),

        // 카테고리 퀵 선택
        Wrap(
          spacing: 8,
          children: ['신발', '의류', '가방', '악세사리'].map((cat) {
            final isSelected = _categoryController.text == cat;
            return FilterChip(
              label: Text(cat, style: const TextStyle(fontSize: 13)),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _categoryController.text = isSelected ? '' : cat;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // 직접 입력 (퀵 선택 후 수정 or 직접 타이핑)
        TextFormField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: '카테고리 (선택 또는 직접 입력)',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
            hintText: '예: 스니커즈, 패딩, 크로스백...',
          ),
          onChanged: (_) => setState(() {}), // 칩 선택 상태 동기화
        ),
        const SizedBox(height: 12),

        // 이미지 URL
        TextFormField(
          controller: _imageUrlController,
          decoration: const InputDecoration(
            labelText: '이미지 URL (선택)',
            prefixIcon: Icon(Icons.image_outlined),
            border: OutlineInputBorder(),
            hintText: 'https://...',
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
        ),

        // 이미지 미리보기
        if (_imageUrlController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _imageUrlController.text,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 48,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Text('이미지 로드 실패',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
              ),
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

            // 사이즈 KR + 피커 버튼
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: entry.sizeKrController,
                decoration: InputDecoration(
                  labelText: 'KR',
                  border: const OutlineInputBorder(),
                  hintText: '270',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: _sizeCharts.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.list_alt, size: 18),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: '사이즈 선택',
                          onPressed: () => _openSizePicker(entry),
                        )
                      : null,
                ),
                onChanged: (_) => _autoFillEuSize(entry),
                validator: (v) => (v == null || v.trim().isEmpty) ? '필수' : null,
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
                  onTap:
                      entry.qty > 1 ? () => setState(() => entry.qty--) : null,
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
                  initialValue: validSourceId,
                  decoration: InputDecoration(
                    labelText:
                        '매입처 (${filterType == 'online' ? '온라인' : '오프라인'})',
                    prefixIcon: const Icon(Icons.store),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('선택 안함')),
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
                      style:
                          TextStyle(color: Colors.blue.shade700, fontSize: 13),
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

// ══════════════════════════════════════
// 브랜드 검색 피커 시트
// ══════════════════════════════════════

class _BrandPickerSheet extends StatefulWidget {
  final List<Brand> brands;
  final List<String> recentBrandIds;
  final String? selectedBrandId;

  const _BrandPickerSheet({
    required this.brands,
    required this.recentBrandIds,
    this.selectedBrandId,
  });

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
    final recentBrands = widget.recentBrandIds
        .map((id) => widget.brands.cast<Brand?>()
            .firstWhere((b) => b?.id == id, orElse: () => null))
        .whereType<Brand>()
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 드래그 핸들
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 타이틀 + 선택 안함
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
            // 검색창
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
            // 최근 선택 핀 행
            if (recentBrands.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('최근 선택',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: recentBrands.map((brand) {
                    final isSelected = brand.id == widget.selectedBrandId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(brand.name,
                            style: const TextStyle(fontSize: 13)),
                        selected: isSelected,
                        onSelected: (_) => Navigator.pop(context, brand),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
            ],
            // 전체 브랜드 목록
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('검색 결과가 없습니다',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final brand = _filtered[i];
                        final isSelected =
                            brand.id == widget.selectedBrandId;
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
