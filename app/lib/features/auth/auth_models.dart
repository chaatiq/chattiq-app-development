/// The signed-in Chattiq account (fields the app reads from the API).
class AppUser {
  const AppUser({required this.id, required this.email, this.userName = '', this.role = ''});

  final String id;
  final String email;
  final String userName;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: '${json['id'] ?? ''}',
    email: '${json['email'] ?? ''}',
    userName: '${json['userName'] ?? ''}',
    role: '${json['role'] ?? ''}',
  );

  /// Name to show: user name, or the email when there is none.
  String get displayName => userName.trim().isNotEmpty ? userName : email;
}

enum AuthStatus { loading, signedIn, signedOut }

class AuthState {
  const AuthState(this.status, {this.user});

  const AuthState.loading() : this(AuthStatus.loading);
  const AuthState.signedOut() : this(AuthStatus.signedOut);

  final AuthStatus status;

  /// Null while signed out, or when signed in but the profile could not be loaded (offline).
  final AppUser? user;
}
