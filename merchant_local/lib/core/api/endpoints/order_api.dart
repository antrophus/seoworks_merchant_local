import '../poizon_client.dart';

const _basePath = '/dop/api/v1/pop/api/v1';

/// POIZON Order & Fulfillment API — 주문/배송 관리
class OrderApi {
  final PoizonClient _client;
  const OrderApi(this._client);

  // ── 주문 조회 ─────────────────────────────────────────

  /// 주문 목록 조회 V2 (유형별 지원)
  Future<Map<String, dynamic>> queryOrderList({
    String? orderType,
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return _client.post('$_basePath/order/list/v2', {
      if (orderType != null) 'orderType': orderType,
      'pageNum': pageNum,
      'pageSize': pageSize,
    });
  }

  /// 주문 QC 결과 조회
  Future<Map<String, dynamic>> queryOrderQcResult({
    required String orderId,
  }) {
    return _client.post('$_basePath/order/qc-result', {'orderId': orderId});
  }

  /// 주문 서류 조회
  Future<Map<String, dynamic>> getOrderPaper({
    required String orderId,
  }) {
    return _client.post('$_basePath/order/paper', {'orderId': orderId});
  }

  // ── 배송 처리 ─────────────────────────────────────────

  /// 주문 발송 처리
  Future<Map<String, dynamic>> shipOrder({
    required String orderId,
    required String trackingNo,
    required String carrierCode,
  }) {
    return _client.post('$_basePath/fulfillment/ship', {
      'orderId': orderId,
      'trackingNo': trackingNo,
      'carrierCode': carrierCode,
    });
  }

  /// 지원 운송사 목록 조회
  Future<Map<String, dynamic>> getSupportedCarriers() {
    return _client.post('$_basePath/fulfillment/carriers', {});
  }
}
