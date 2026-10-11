import 'package:aquara_mobile/services/token_store.dart';

class FakeTokenStore implements TokenStore {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String token) async {
    if (failWrite) throw StateError('write failed');
    value = token;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('delete failed');
    value = null;
  }
}
