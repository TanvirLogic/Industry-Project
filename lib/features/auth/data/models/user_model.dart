import '../../data/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    super.token,
    super.refreshToken,
    super.phone,
    super.avatarUrl,
    super.city,
    super.role,
    super.emailVerified,
    super.phoneVerified,
  });

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    String? token,
    String? refreshToken,
  }) {
    final rawId = json['_id'] ?? json['id']?.toString() ?? '';
    return UserModel(
      id: rawId.toString(),
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      token: token ?? json['token'],
      refreshToken: refreshToken ?? json['refreshToken'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      city: json['city'],
      role: json['role'] is int
          ? json['role'] as int
          : json['role'] is String
          ? (json['role'] == 'MENTOR' ? 1 : 0)
          : null,
      emailVerified: json['email_verified'],
      phoneVerified: json['phone_verified'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'token': token,
      'refreshToken': refreshToken,
      'phone': phone,
      'avatar_url': avatarUrl,
      'city': city,
      'role': role,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
    };
  }
}
