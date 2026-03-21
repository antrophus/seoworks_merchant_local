import '../poizon_client.dart';

const _basePath = '/dop/api/v1/pop/api/v1';

/// POIZON Listing & Inventory API — 리스팅 관리
class ListingApi {
  final PoizonClient _client;
  const ListingApi(this._client);

  // ── 최저가 추천 ───────────────────────────────────────

  /// 단건 최저가 추천 조회
  Future<Map<String, dynamic>> getRecommendedPrice({
    required String globalSkuId,
    String countryCode = 'KR',
  }) {
    return _client.post('$_basePath/recommend-bid', {
      'globalSkuId': globalSkuId,
      'countryCode': countryCode,
    });
  }

  /// 배치 최저가 추천 조회
  Future<Map<String, dynamic>> getRecommendedPriceBatch({
    required List<String> globalSkuIds,
    String countryCode = 'KR',
  }) {
    return _client.post('$_basePath/recommend-bid/batch', {
      'globalSkuIds': globalSkuIds,
      'countryCode': countryCode,
    });
  }

  // ── 리스팅 등록 ───────────────────────────────────────

  /// Ship-to-verify 리스팅 등록
  Future<Map<String, dynamic>> submitShipToVerify({
    required String requestId,
    required String skuId,
    required int price,
    required int quantity,
    String countryCode = 'KR',
    String? currency,
    String? sizeType,
  }) {
    return _client.post(
      '$_basePath/submit-bid/normal-autonomous-bidding',
      {
        'requestId': requestId,
        'skuId': skuId,
        'price': price,
        'quantity': quantity,
        'countryCode': countryCode,
        if (currency != null) 'currency': currency,
        if (sizeType != null) 'sizeType': sizeType,
      },
    );
  }

  /// 리스팅 취소
  Future<Map<String, dynamic>> cancelListing({
    required String bidId,
  }) {
    return _client.post('$_basePath/cancel-bid', {'bidId': bidId});
  }

  // ── 리스팅 조회 ───────────────────────────────────────

  /// 리스팅 목록 조회 (간편 버전)
  Future<Map<String, dynamic>> queryListingSimple({
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return _client.post('$_basePath/query-bid/simple-list', {
      'pageNum': pageNum,
      'pageSize': pageSize,
    });
  }

  /// 리스팅 목록 전체 조회
  Future<Map<String, dynamic>> queryListingList({
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return _client.post('$_basePath/query-bid/list', {
      'pageNum': pageNum,
      'pageSize': pageSize,
    });
  }
}
