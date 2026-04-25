class UserModel {
  static const String adminRole = 'admin';
  static const String userRole = 'user';

  final String uid;
  final String name;
  final String email;
  final String role;
  final double balance;
  final bool isActive;
  final bool isDeleted;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.balance,
    required this.isActive,
    required this.isDeleted,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      balance: (data['balance'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'balance': balance,
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  bool get isAdmin => role == adminRole; // computed expression -> true, false
  bool get canAccessApp => isActive && !isDeleted;
}
