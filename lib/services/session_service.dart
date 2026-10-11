import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'token_store.dart';

/// A point-in-time credential. Never log [token].
class SessionSnapshot {
  const SessionSnapshot._(this.token, this.revision);

  final String? token;
  final int revision;

  bool get isAuthenticated => token != null;

  @override
  String toString() => 'SessionSnapshot(authenticated: $isAuthenticated)';
}

/// Share one instance across Auth and API clients. Credentials are persisted only
/// through OS-backed secure storage; storage failures never fall back to prefs.
class SessionService {
  SessionService({
    Future<void> Function()? clearLegacySession,
    TokenStore? store,
  }) : _clearLegacySession = clearLegacySession ?? _removeLegacySession,
       _store = store ?? SecureTokenStore();

  static final SessionService instance = SessionService();

  final Future<void> Function() _clearLegacySession;
  final TokenStore _store;
  bool _pendingDelete = false;
  final _changes = StreamController<int>.broadcast();
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;
  String? _token;
  Map<String, String> _metadata = const {};
  int _revision = 0;
  int _metadataVersion = 0;
  int get metadataVersion => _metadataVersion;

  /// Presentation only, never evidence of backend authorization.
  Map<String, String> get metadata => _metadata;
  int get revision => _revision;
  bool get hasSession => _initialized && !_pendingDelete && _token != null;
  bool owns(SessionSnapshot snapshot) =>
      !_disposed && hasSession && snapshot.revision == _revision;

  Map<String, String> _minimumMetadata(Map<String, dynamic> user) =>
      Map.unmodifiable({
        'user_id': user['id'].toString(),
        'user_name': user['name'] as String,
        'foto_profil': user['foto_profil'] as String? ?? '',
      });

  /// Commit and revision check share the credential queue. No plaintext writes.
  Future<bool> updateMetadata(
    SessionSnapshot expected,
    Map<String, dynamic> user, {
    int? expectedMetadataVersion,
  }) => _serialized(() async {
    if (!owns(expected)) return false;
    if (expectedMetadataVersion != null &&
        expectedMetadataVersion != _metadataVersion) {
      return false;
    }
    if (user['id'] is! int ||
        user['name'] is! String ||
        (user['foto_profil'] != null && user['foto_profil'] is! String)) {
      throw const FormatException('Data pengguna tidak valid.');
    }
    final id = _metadata['user_id'];
    if (id != null && id != user['id'].toString()) return false;
    _metadata = _minimumMetadata(user);
    _metadataVersion++;
    // Same revision: profile refresh is NOT logout/account replacement.
    _changes.add(_revision);
    return true;
  });

  /// Credential-free notifications; consumers can later react without Navigator
  /// or BuildContext dependencies in the service layer.
  Stream<int> get changes => _changes.stream;

  static Future<void> _removeLegacySession() async {
    final preferences = await SharedPreferences.getInstance();
    const keys = ['token', 'user_id', 'user_name', 'foto_profil'];
    for (final key in keys) {
      if (!await preferences.remove(key)) {
        throw StateError('Pembersihan sesi lokal gagal.');
      }
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) async {
      if (_disposed) throw StateError('Layanan sesi sudah ditutup.');
      return operation();
    });
    // A failed operation must not poison subsequent cleanup/recovery attempts.
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _pendingDelete =
        _pendingDelete || (prefs.getBool('session_delete_pending') ?? false);
    if (_pendingDelete) {
      await _deletePersisted();
    }
    // Never import the old plaintext token. Fail closed if cleanup fails.
    await _clearLegacySession();
    final stored = await _store.read();
    if (stored != null && !_validToken(stored)) {
      await _store.delete();
      throw StateError('Token tersimpan tidak valid. Silakan login ulang.');
    }
    _token = stored;
    _initialized = true;
  }

  Future<SessionSnapshot> snapshot() => _serialized(() async {
    await _initialize();
    return SessionSnapshot._(_token, _revision);
  });

  Future<String?> readToken() async => (await snapshot()).token;

  static bool _validToken(String token) =>
      token.isNotEmpty &&
      token.length <= 4096 &&
      RegExp(r'^[\x21-\x7E]+$').hasMatch(token);

  Future<void> saveToken(String token) async {
    await saveIfCurrent(token);
  }

  Future<bool> saveIfCurrent(
    String token, {
    SessionSnapshot? expected,
    Map<String, dynamic>? user,
  }) => _serialized(() async {
    // Treat Sanctum tokens as opaque printable bearer credentials, not JWTs.
    if (!_validToken(token)) {
      throw ArgumentError('Token sesi tidak valid.');
    }
    await _initialize();
    if (expected != null && expected.revision != _revision) return false;
    try {
      await _store.write(token);
      _metadata = user == null ? const {} : _minimumMetadata(user);
    } catch (_) {
      _token = null;
      _metadata = const {};
      _pendingDelete = true;
      _initialized = false;
      _revision++;
      _changes.add(_revision);
      // Best effort rollback; reads remain blocked until deletion succeeds.
      try {
        await _deletePersisted();
      } catch (_) {}
      rethrow;
    }
    _token = token;
    _revision++;
    _changes.add(_revision);
    return true;
  });

  Future<void> _deletePersisted() async {
    // A non-secret tombstone prevents restoring a token after a failed deletion
    // followed by process restart. It is never used as proof of authentication.
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('session_delete_pending', true)) {
      throw StateError('Penanda penghapusan sesi gagal disimpan.');
    }
    await _store.delete();
    for (final key in ['token', 'user_id', 'user_name', 'foto_profil']) {
      if (!await prefs.remove(key)) throw StateError('Pembersihan sesi gagal.');
    }
    if (!await prefs.remove('session_delete_pending')) {
      throw StateError('Penanda penghapusan sesi gagal dibersihkan.');
    }
    _pendingDelete = false;
  }

  /// Clears even when legacy cleanup fails. The error is propagated so callers
  /// cannot report that disk cleanup succeeded when it did not.
  Future<void> clear() => _serialized(() async {
    _token = null;
    _metadata = const {};
    _revision++;
    _changes.add(_revision);
    _initialized = false;
    _pendingDelete = true;
    await _initialize();
  });

  /// A response from an older login must never invalidate the new login.
  Future<bool> invalidate(SessionSnapshot expected) => _serialized(() async {
    if (_revision != expected.revision || _token == null) return false;
    _token = null;
    _metadata = const {};
    _revision++;
    _changes.add(_revision);
    _initialized = false;
    _pendingDelete = true;
    await _initialize();
    return true;
  });

  Future<bool> isCurrent(SessionSnapshot expected) => _serialized(() async {
    return _revision == expected.revision;
  });

  Future<void> dispose() => _serialized(() async {
    _token = null;
    _metadata = const {};
    _revision++;
    _disposed = true;
    // Do not wait for paused subscribers before disposing credentials.
    unawaited(_changes.close());
  });
}
