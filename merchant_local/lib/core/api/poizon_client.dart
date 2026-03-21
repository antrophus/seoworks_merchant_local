import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'poizon_signer.dart';

const _baseUrl = 'https://open.poizon.com';
const _language = 'ko';
const _timeZone = 'Asia/Seoul';

const _keyAppKey = 'poizon_app_key';
const _keyAppSecret = 'poizon_app_secret';

final _logger = Logger();

/// POIZON Open API HTTP 클라이언트
///
/// 사용 전 [PoizonClient.configure]로 App Key/Secret 등록 필요
class PoizonClient {
  static final PoizonClient _instance = PoizonClient._internal();
  factory PoizonClient() => _instance;
  PoizonClient._internal();

  final _storage = const FlutterSecureStorage();
  Dio? _dio;
  PoizonSigner? _signer;

  /// App Key / Secret 초기화 (앱 설정 화면에서 1회 호출)
  Future<void> configure({
    required String appKey,
    required String appSecret,
  }) async {
    await _storage.write(key: _keyAppKey, value: appKey);
    await _storage.write(key: _keyAppSecret, value: appSecret);
    _init(appKey, appSecret);
  }

  /// 저장된 자격증명으로 클라이언트 복원 (앱 시작 시 호출)
  Future<bool> restore() async {
    final appKey = await _storage.read(key: _keyAppKey);
    final appSecret = await _storage.read(key: _keyAppSecret);
    if (appKey == null || appSecret == null) return false;
    _init(appKey, appSecret);
    return true;
  }

  bool get isConfigured => _signer != null;

  void _init(String appKey, String appSecret) {
    _signer = PoizonSigner(appKey: appKey, appSecret: appSecret);
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// POST 요청 (대부분의 POIZON API)
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    _checkConfigured();
    final signedBody = _signer!.sign({
      ...body,
      'language': _language,
      'timeZone': _timeZone,
    });

    try {
      final response = await _dio!.post(path, data: signedBody);
      _checkResponse(response.data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('POIZON API POST 오류: $path', error: e);
      rethrow;
    }
  }

  /// GET 요청 (Bill / 일부 Bonded API)
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> queryParams,
  ) async {
    _checkConfigured();
    final signedParams = _signer!.sign({
      ...queryParams,
      'language': _language,
      'timeZone': _timeZone,
    });

    try {
      final response = await _dio!.get(
        path,
        queryParameters: signedParams,
      );
      _checkResponse(response.data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('POIZON API GET 오류: $path', error: e);
      rethrow;
    }
  }

  void _checkConfigured() {
    if (_signer == null || _dio == null) {
      throw StateError('PoizonClient가 초기화되지 않았습니다. configure() 또는 restore()를 먼저 호출하세요.');
    }
  }

  void _checkResponse(dynamic data) {
    if (data is Map && data['code'] != 200) {
      throw PoizonApiException(
        code: data['code'] as int? ?? -1,
        message: data['msg'] as String? ?? '알 수 없는 오류',
      );
    }
  }
}

class PoizonApiException implements Exception {
  final int code;
  final String message;
  const PoizonApiException({required this.code, required this.message});

  @override
  String toString() => 'PoizonApiException [$code]: $message';
}
