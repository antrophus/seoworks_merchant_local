import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref.read(skuSearchQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(skuSearchResultProvider);

    return Column(
      children: [
        // 검색 바
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '품번, 상품명, 브랜드로 검색',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  ref.read(skuSearchQueryProvider.notifier).state = '';
                },
              ),
            ),
            onSubmitted: (_) => _onSearch(),
            textInputAction: TextInputAction.search,
          ),
        ),

        // 검색 결과
        Expanded(
          child: results.when(
            data: (items) {
              if (ref.watch(skuSearchQueryProvider).isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '품번 또는 상품명으로 검색하세요',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '검색 결과가 없습니다',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'POIZON API 연동 후 상품 데이터가 표시됩니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: item.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported,
                                size: 48,
                              ),
                            ),
                          )
                        : const Icon(Icons.inventory_2, size: 48),
                    title: Text(item.productName),
                    subtitle: Text(
                      [
                        if (item.brandName != null) item.brandName!,
                        if (item.articleNumber != null) item.articleNumber!,
                        if (item.sizeInfo != null) item.sizeInfo!,
                      ].join(' / '),
                    ),
                    trailing: Text(
                      item.id,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}
