import '../models/scan_result.dart';
import 'api_service.dart';

class VisionCaptureResponse {
  final String imageBase64;
  final List<double>? featureVector;
  final bool isLoose;
  final int frameSizeBytes;

  VisionCaptureResponse({
    required this.imageBase64,
    this.featureVector,
    required this.isLoose,
    required this.frameSizeBytes,
  });

  factory VisionCaptureResponse.fromJson(Map<String, dynamic> json) {
    List<double>? vector;
    if (json['feature_vector'] != null && json['feature_vector'] is List) {
      vector = (json['feature_vector'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }
    return VisionCaptureResponse(
      imageBase64: json['image_base64'] as String? ?? '',
      featureVector: vector,
      isLoose: json['is_loose'] as bool? ?? false,
      frameSizeBytes: json['frame_size_bytes'] as int? ?? 0,
    );
  }
}

class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  final ApiService _api = ApiService();

  Future<ScanResult> matchFromEsp32({
    String? esp32Url,
    double threshold = 0.78,
  }) async {
    final body = {
      'capture_from_esp32': true,
      'esp32_cam_url': esp32Url ?? _api.esp32Url,
      'similarity_threshold': threshold,
    };

    final response = await _api.post('/api/products/match/', body: body);
    return ScanResult.fromJson(response as Map<String, dynamic>);
  }

  Future<ScanResult> matchFromBase64({
    required String imageBase64,
    double threshold = 0.78,
  }) async {
    final body = {
      'image_base64': imageBase64,
      'similarity_threshold': threshold,
    };

    final response = await _api.post('/api/products/match/', body: body);
    return ScanResult.fromJson(response as Map<String, dynamic>);
  }

  Future<VisionCaptureResponse> captureFrameFromEsp32([String? customUrl]) async {
    final body = {
      'esp32_cam_url': customUrl ?? _api.esp32Url,
    };

    final response = await _api.post('/api/vision/capture/', body: body);
    return VisionCaptureResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<List<double>?> generateEmbedding(String imageBase64) async {
    final body = {'image_base64': imageBase64};
    final response = await _api.post('/api/vision/embed/', body: body);
    if (response is Map<String, dynamic> && response['feature_vector'] is List) {
      return (response['feature_vector'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }
    return null;
  }
}
