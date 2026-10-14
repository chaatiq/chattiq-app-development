import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_api.dart';
import 'api/api_client.dart';
import 'auth/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokens: ref.watch(tokenStorageProvider)));

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
