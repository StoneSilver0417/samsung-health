import 'dart:convert';

/// Gemini API 요청/응답 Typed DTO 정의.
/// Dynamic JSON 파싱을 완전히 격리하여 타입 안정성을 보장한다.

class GeminiPartDto {
  final String text;
  final bool thought;

  const GeminiPartDto({
    required this.text,
    this.thought = false,
  });

  factory GeminiPartDto.fromJson(Map<String, dynamic> json) {
    return GeminiPartDto(
      text: json['text'] as String? ?? '',
      thought: json['thought'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'text': text};
    if (thought) {
      map['thought'] = true;
    }
    return map;
  }
}

class GeminiContentDto {
  final List<GeminiPartDto> parts;

  const GeminiContentDto({required this.parts});

  factory GeminiContentDto.text(String text) {
    return GeminiContentDto(
      parts: [GeminiPartDto(text: text)],
    );
  }

  factory GeminiContentDto.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'] as List? ?? const [];
    final parts = rawParts
        .whereType<Map>()
        .map((p) => GeminiPartDto.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    return GeminiContentDto(parts: parts);
  }

  Map<String, dynamic> toJson() {
    return {
      'parts': parts.map((p) => p.toJson()).toList(),
    };
  }
}

class GeminiGenerationConfigDto {
  final int maxOutputTokens;

  const GeminiGenerationConfigDto({this.maxOutputTokens = 2048});

  factory GeminiGenerationConfigDto.fromJson(Map<String, dynamic> json) {
    return GeminiGenerationConfigDto(
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 2048,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxOutputTokens': maxOutputTokens,
    };
  }
}

class GeminiGenerateRequestDto {
  final List<GeminiContentDto> contents;
  final GeminiGenerationConfigDto generationConfig;

  const GeminiGenerateRequestDto({
    required this.contents,
    this.generationConfig = const GeminiGenerationConfigDto(),
  });

  factory GeminiGenerateRequestDto.textPrompt(
    String prompt, {
    int maxOutputTokens = 2048,
  }) {
    return GeminiGenerateRequestDto(
      contents: [GeminiContentDto.text(prompt)],
      generationConfig: GeminiGenerationConfigDto(
        maxOutputTokens: maxOutputTokens,
      ),
    );
  }

  factory GeminiGenerateRequestDto.fromJson(Map<String, dynamic> json) {
    final rawContents = json['contents'] as List? ?? const [];
    final contents = rawContents
        .whereType<Map>()
        .map((c) => GeminiContentDto.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    final configMap = json['generationConfig'] as Map<String, dynamic>?;
    final config = configMap != null
        ? GeminiGenerationConfigDto.fromJson(configMap)
        : const GeminiGenerationConfigDto();
    return GeminiGenerateRequestDto(
      contents: contents,
      generationConfig: config,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contents': contents.map((c) => c.toJson()).toList(),
      'generationConfig': generationConfig.toJson(),
    };
  }

  String toRawJson() => jsonEncode(toJson());
}

class GeminiCandidateDto {
  final GeminiContentDto? content;

  const GeminiCandidateDto({this.content});

  factory GeminiCandidateDto.fromJson(Map<String, dynamic> json) {
    final contentMap = json['content'] as Map<String, dynamic>?;
    return GeminiCandidateDto(
      content: contentMap != null
          ? GeminiContentDto.fromJson(contentMap)
          : null,
    );
  }
}

class GeminiGenerateResponseDto {
  final List<GeminiCandidateDto> candidates;

  const GeminiGenerateResponseDto({this.candidates = const []});

  factory GeminiGenerateResponseDto.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'] as List? ?? const [];
    final candidates = rawCandidates
        .whereType<Map>()
        .map((c) => GeminiCandidateDto.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    return GeminiGenerateResponseDto(candidates: candidates);
  }

  factory GeminiGenerateResponseDto.fromRawJson(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return GeminiGenerateResponseDto.fromJson(map);
  }

  /// 모델의 내부 사고(`thought: true`)를 제외하고 정제된 응답 텍스트를 추출한다.
  String extractCleanText() {
    if (candidates.isEmpty) {
      throw Exception('Gemini 응답에 결과가 없습니다');
    }
    final content = candidates.first.content;
    final parts = content?.parts;
    final text = parts
        ?.where((p) => !p.thought)
        .map((p) => p.text)
        .join('')
        .trim();
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답이 비어있습니다');
    }
    return text;
  }
}
