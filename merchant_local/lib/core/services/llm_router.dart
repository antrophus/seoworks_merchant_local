import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

// ══════════════════════════════════════════════════
// LLM 프로바이더 설정
// ══════════════════════════════════════════════════

const _keyClaudeApiKey = 'llm_claude_api_key';
const _keyGrokApiKey = 'llm_grok_api_key';
const _keyDeepseekApiKey = 'llm_deepseek_api_key';

enum LlmProvider { claude, grok, deepseek }

class _ProviderConfig {
  final String name;
  final String baseUrl;
  final String model;
  final String storageKey;

  const _ProviderConfig({
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.storageKey,
  });
}

const _providers = <LlmProvider, _ProviderConfig>{
  LlmProvider.claude: _ProviderConfig(
    name: 'Claude',
    baseUrl: 'https://api.anthropic.com/v1/messages',
    model: 'claude-sonnet-4-20250514',
    storageKey: _keyClaudeApiKey,
  ),
  LlmProvider.grok: _ProviderConfig(
    name: 'Grok',
    baseUrl: 'https://api.x.ai/v1/chat/completions',
    model: 'grok-4-1-fast-non-reasoning',
    storageKey: _keyGrokApiKey,
  ),
  LlmProvider.deepseek: _ProviderConfig(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/chat/completions',
    model: 'deepseek-chat',
    storageKey: _keyDeepseekApiKey,
  ),
};

// ══════════════════════════════════════════════════
// 상품 인식 결과
// ══════════════════════════════════════════════════

class ProductRecognitionResult {
  final String? brand;
  final String? modelCode;
  final String? modelName;
  final String? sizeKr;
  final String? barcode;
  final String? category;
  final String? gender;
  final String providerUsed;
  final String rawResponse;

  const ProductRecognitionResult({
    this.brand,
    this.modelCode,
    this.modelName,
    this.sizeKr,
    this.barcode,
    this.category,
    this.gender,
    required this.providerUsed,
    required this.rawResponse,
  });

  bool get hasUsefulData =>
      brand != null || modelCode != null || modelName != null;
}

// ══════════════════════════════════════════════════
// LLM Router (캐스케이딩)
// ══════════════════════════════════════════════════

class LlmRouter {
  static final LlmRouter _instance = LlmRouter._internal();
  factory LlmRouter() => _instance;
  LlmRouter._internal();

  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  /// API 키 저장
  Future<void> setApiKey(LlmProvider provider, String apiKey) async {
    await _storage.write(key: _providers[provider]!.storageKey, value: apiKey);
  }

  /// API 키 조회
  Future<String?> getApiKey(LlmProvider provider) async {
    return _storage.read(key: _providers[provider]!.storageKey);
  }

  /// API 키 삭제
  Future<void> removeApiKey(LlmProvider provider) async {
    await _storage.delete(key: _providers[provider]!.storageKey);
  }

  /// 사용 가능한 프로바이더 목록
  Future<List<LlmProvider>> getAvailableProviders() async {
    final result = <LlmProvider>[];
    for (final provider in LlmProvider.values) {
      final key = await getApiKey(provider);
      if (key != null && key.isNotEmpty) {
        result.add(provider);
      }
    }
    return result;
  }

  /// 상품 이미지 인식 (캐스케이딩)
  Future<ProductRecognitionResult> recognizeProduct(
      Uint8List imageBytes) async {
    final providers = await getAvailableProviders();
    if (providers.isEmpty) {
      throw const LlmException('설정된 LLM API 키가 없습니다. 설정에서 API 키를 등록하세요.');
    }

    for (final provider in providers) {
      try {
        _logger.i('LLM 상품 인식 시도: ${_providers[provider]!.name}');
        final result = await _callProvider(provider, imageBytes);
        _logger.i('LLM 상품 인식 성공: ${_providers[provider]!.name}');
        return result;
      } catch (e) {
        _logger.w('LLM ${_providers[provider]!.name} 실패, 다음 프로바이더로 폴백',
            error: e);
        if (provider == providers.last) {
          throw LlmException('모든 LLM 프로바이더 호출 실패: $e');
        }
      }
    }
    throw const LlmException('사용 가능한 LLM 프로바이더가 없습니다');
  }

  // ── 프로바이더별 호출 ──

  Future<ProductRecognitionResult> _callProvider(
      LlmProvider provider, Uint8List imageBytes) async {
    final config = _providers[provider]!;
    final apiKey = await getApiKey(provider);
    if (apiKey == null) throw LlmException('${config.name} API 키 없음');

    final base64Image = base64Encode(imageBytes);

    switch (provider) {
      case LlmProvider.claude:
        return _callClaude(config, apiKey, base64Image);
      case LlmProvider.grok:
      case LlmProvider.deepseek:
        return _callOpenAICompatible(config, apiKey, base64Image, provider);
    }
  }

  /// Claude (Anthropic Messages API)
  Future<ProductRecognitionResult> _callClaude(
      _ProviderConfig config, String apiKey, String base64Image) async {
    final response = await _dio.post(
      config.baseUrl,
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      }),
      data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': _prompt},
            ],
          }
        ],
      },
    );

    final text = response.data['content'][0]['text'] as String? ?? '';
    return _parseResponse(text, config.name);
  }

  /// OpenAI-compatible API (Grok, DeepSeek)
  Future<ProductRecognitionResult> _callOpenAICompatible(_ProviderConfig config,
      String apiKey, String base64Image, LlmProvider provider) async {
    final response = await _dio.post(
      config.baseUrl,
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      }),
      data: {
        'model': config.model,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                  'detail': 'high',
                },
              },
              {'type': 'text', 'text': _prompt},
            ],
          }
        ],
      },
    );

    final text =
        response.data['choices'][0]['message']['content'] as String? ?? '';
    return _parseResponse(text, config.name);
  }

  // ── 프롬프트 ──

  static const _prompt = '''
이 신발/의류/가방 사진을 분석해서 아래 정보를 JSON으로 추출해주세요.
반드시 JSON만 응답하세요 (마크다운 코드블록 없이).

{
  "brand": "브랜드명 (예: Nike, Adidas, New Balance)",
  "model_code": "품번/모델코드 (예: DZ5485-612, 550BB)",
  "model_name": "모델명 (예: Nike Dunk Low Retro)",
  "size_kr": "한국 사이즈 (보이면, 예: 270)",
  "barcode": "바코드 숫자 (보이면)",
  "category": "카테고리 (sneakers/bag/clothing/accessory)",
  "gender": "성별 (M/W/GS/PS/TD/unisex)"
}

확실하지 않은 필드는 null로 응답하세요.
''';

  // ── 모델코드 정규화: 공백→하이픈, 연속 하이픈 제거 ──
  String? _normalizeModelCode(String? code) {
    if (code == null || code.isEmpty) return code;
    return code
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-');
  }

  // ── 응답 파싱 ──

  ProductRecognitionResult _parseResponse(String raw, String providerName) {
    // JSON 추출 (코드블록 감싸져 있을 수 있음)
    var jsonStr = raw.trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
    if (jsonMatch != null) {
      jsonStr = jsonMatch.group(0)!;
    }

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ProductRecognitionResult(
        brand: map['brand'] as String?,
        modelCode: _normalizeModelCode(map['model_code'] as String?),
        modelName: map['model_name'] as String?,
        sizeKr: map['size_kr']?.toString(),
        barcode: map['barcode']?.toString(),
        category: map['category'] as String?,
        gender: map['gender'] as String?,
        providerUsed: providerName,
        rawResponse: raw,
      );
    } catch (e) {
      _logger.w('LLM 응답 JSON 파싱 실패', error: e);
      return ProductRecognitionResult(
        providerUsed: providerName,
        rawResponse: raw,
      );
    }
  }
}

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);
  @override
  String toString() => 'LlmException: $message';
}
