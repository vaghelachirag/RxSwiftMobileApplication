/// Mirrors the `data` block from the login response envelope.
///
/// ```json
/// {
///   "token": "eyJ...",
///   "user": { ... }
/// }
/// ```
class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    required this.user,
  });

  final String token;
  final UserModel user;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': user.toJson(),
  };

  @override
  String toString() => 'LoginResponseModel(token: $token, user: $user)';
}

/// Nested user object returned inside the login response.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.profileImage,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final String? profileImage;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:           json['id'] as String,
      fullName:     json['fullName'] as String,
      email:        json['email'] as String,
      phone:        json['phone'] as String,
      role:         json['role'] as String,
      isActive:     json['isActive'] as bool,
      createdAt:    DateTime.parse(json['createdAt'] as String),
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'fullName':     fullName,
    'email':        email,
    'phone':        phone,
    'role':         role,
    'isActive':     isActive,
    'createdAt':    createdAt.toIso8601String(),
    'profileImage': profileImage,
  };

  @override
  String toString() =>
      'UserModel(id: $id, fullName: $fullName, email: $email, role: $role)';
}