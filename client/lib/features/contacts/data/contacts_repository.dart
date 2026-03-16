import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/contact.dart';

class ContactsRepository {
  final _api = ApiClient().dio;
  
  Future<List<Contact>> getContacts({int limit = 50, int offset = 0}) async {
    final response = await _api.get('/contacts?limit=$limit&offset=$offset');
    final data = response.data['data'] ?? response.data;
    final List<dynamic> contacts = data is List ? data : (data['contacts'] ?? []);
    return contacts.map((json) => Contact.fromJson(json)).toList();
  }
  
  Future<Map<String, dynamic>> searchUserByPhone(String phone) async {
    final response = await _api.get('/users/search', queryParameters: {'phone': phone});
    final data = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(data);
  }
  
  Future<String> addContact(String contactId, {String? remark}) async {
    try {
      final response = await _api.post('/contacts/request', data: {
        'contact_id': contactId,
        'remark': remark,
      });
      return 'success';
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          final code = data['code'];
          if (code == 'CONTACT_ALREADY_EXISTS') {
            return 'already_exists';
          }
          return data['message']?.toString() ?? '添加失败';
        }
      }
      return '网络错误，请重试';
    } catch (e) {
      return '添加失败: $e';
    }
  }
  
  Future<void> acceptContact(String contactId) async {
    await _api.post('/contacts/accept/$contactId');
  }
  
  Future<void> deleteContact(String contactId) async {
    await _api.delete('/contacts/$contactId');
  }
}