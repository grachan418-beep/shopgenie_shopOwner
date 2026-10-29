import '../models/worker.dart';
import 'api_service.dart';

class WorkerService {
  final ApiService _api = ApiService();

  Future<List<Worker>> getWorkers() async {
    final response = await _api.get('/api/workers/');
    if (response is! List) {
      throw ApiException('The server returned an invalid worker list.');
    }
    return response
        .map((item) => Worker.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CreatedWorker> createWorker({
    required String name,
    required String phone,
    required Map<String, bool> permissions,
  }) async {
    final response = await _api.post('/api/workers/', body: {
      'name': name.trim(),
      'phone': phone.trim(),
      'permissions': permissions,
    });
    return CreatedWorker.fromJson(response as Map<String, dynamic>);
  }

  Future<Worker> updateWorker(
    int id, {
    String? name,
    String? phone,
    Map<String, bool>? permissions,
    bool? isActive,
  }) async {
    final response = await _api.patch(
      '/api/workers/$id/',
      body: {
        if (name != null) 'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (permissions != null) 'permissions': permissions,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Worker.fromJson(response as Map<String, dynamic>);
  }

  Future<CreatedWorker> regenerateCode(int id) async {
    final response = await _api.post('/api/workers/$id/regenerate-code/');
    return CreatedWorker.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteWorker(int id) async {
    await _api.delete('/api/workers/$id/');
  }
}
