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
  
  Future<void> addContact(String contactId, {String? remark}) async {
    await _api.post('/contacts/request', data: {
      'contact_id': contactId,
      'remark': remark,
    });
  }
  
  Future<void> acceptContact(String contactId) async {
    await _api.post('/contacts/accept/$contactId');
  }
  
  Future<void> deleteContact(String contactId) async {
    await _api.delete('/contacts/$contactId');
  }
}