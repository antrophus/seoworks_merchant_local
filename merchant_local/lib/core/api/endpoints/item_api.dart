import '../poizon_client.dart';

const _basePath = '/dop/api/v1/pop/api/v1/intl-commodity';

/// POIZON Item API — 상품(SKU/SPU) 조회
class ItemApi {
  final PoizonClient _client;
  const ItemApi(this._client);

  /// 품번(Article Number)으로 SPU 조회 (퍼지 검색 지원)
  Future<Map<String, dynamic>> queryByArticleNumber({
    required String articleNumber,
    String region = 'KR',
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return _client.post(
      '$_basePath/intl/spu/spu-basic-info/by-article-number',
      {
        'articleNumber': articleNumber,
        'region': region,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
    );
  }

  /// 바코드로 SKU/SPU 조회 (최대 100개 배치)
  Future<Map<String, dynamic>> queryByBarcodes({
    required List<String> barcodes,
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return _client.post(
      '$_basePath/intl/sku/sku-basic-info/by-barcodes',
      {
        'barcodes': barcodes,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
    );
  }

  /// globalSkuId 배치 조회
  Future<Map<String, dynamic>> queryByGlobalSkuIds({
    required List<String> globalSkuIds,
  }) {
    return _client.post(
      '$_basePath/intl/sku/sku-basic-info/by-globalSkuIds',
      {'globalSkuIds': globalSkuIds},
    );
  }

  /// DW skuId로 조회
  Future<Map<String, dynamic>> queryBySkuId({required String skuId}) {
    return _client.post(
      '$_basePath/intl/sku/sku-basic-info/by-skuid',
      {'skuId': skuId},
    );
  }

  /// 카테고리 트리 조회
  Future<Map<String, dynamic>> queryCategoryTree() {
    return _client.post('$_basePath/intl/category/tree', {});
  }

  /// 브랜드명으로 브랜드 ID 조회
  Future<Map<String, dynamic>> queryBrandByName({
    required String brandName,
  }) {
    return _client.post(
      '$_basePath/intl/brand/by-brandName',
      {'brandName': brandName},
    );
  }
}
