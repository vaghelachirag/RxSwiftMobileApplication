import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../model/login/login_req_model.dart';
import '../../model/login/login_response_model.dart';
import '../utils/token_storage.dart';
import 'auth_repository.dart';
import 'auth_repository_datasource.dart';

/// Concrete implementation of [AuthRepository].
///
/// Responsibilities:
///  1. Delegate HTTP to the datasource.
///  2. On success, persist the token via [TokenStorage].
///  3. Return the result unchanged to the caller.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDatasource datasource,
    required TokenStorage tokenStorage,
  })  : _datasource = datasource,
        _tokenStorage = tokenStorage;

  final AuthRemoteDatasource _datasource;
  final TokenStorage _tokenStorage;

  @override
  Future<ApiResult<LoginResponseModel>> login(LoginRequestModel request) async {
    final result = await _datasource.login(request);

    // Persist token on success so subsequent requests are authorised.
    if (result case ApiSuccess(:final data)) {
      await _tokenStorage.saveToken(data.token);
      await _tokenStorage.saveUserId(data.user.id);
    }

    return result;
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clearAll();
  }
}

// ── Provider ──────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    datasource:   ref.watch(authRemoteDatasourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});