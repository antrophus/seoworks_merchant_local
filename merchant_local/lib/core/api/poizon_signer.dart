import 'dart:convert';
import 'package:crypto/crypto.dart';

/// POIZON Open API MD5 서명 생성기
///
/// 서명 규칙:
/// 1. app_key + timestamp 추가
/// 2. 비어있지 않은 키를 ASCII 오름차순 정렬
/// 3. key=URLencode(value) 형식으로 연결 → stringA
/// 4. stringA 끝에 appSecret 추가 → stringSignTemp
/// 5. MD5(stringSignTemp) → 대문자 = sign
class PoizonSigner {
  final String appKey;
  final String appSecret;

  const PoizonSigner({required this.appKey, required this.appSecret});

  /// 요청 파라미터에 서명 추가 후 반환
  Map<String, dynamic> sign(Map<String, dynamic> params) {
    final data = Map<String, dynamic>.from(params);

    // app_key, timestamp 주입
    data['app_key'] = appKey;
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    // 빈 값 제거
    data.removeWhere(
      (key, value) => value == null || value.toString().isEmpty,
    );

    // ASCII 오름차순 정렬 후 key=URLencode(value) 연결
    final sortedKeys = data.keys.toList()..sort();
    final stringA = sortedKeys
        .map((key) => '$key=${Uri.encodeComponent(_valueToString(data[key]))}')
        .join('&');

    // appSecret 추가 후 MD5 → 대문자
    final stringSignTemp = '$stringA$appSecret';
    final sign = md5
        .convert(utf8.encode(stringSignTemp))
        .toString()
        .toUpperCase();

    data['sign'] = sign;
    return data;
  }

  /// 값 타입별 문자열 변환
  String _valueToString(dynamic value) {
    if (value is List) {
      return value.map((e) => _valueToString(e)).join(',');
    } else if (value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }
}
