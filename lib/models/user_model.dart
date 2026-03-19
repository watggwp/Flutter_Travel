class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? profilePicture;
  final String? bio;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePicture,
    this.bio,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      profilePicture: json['profilePicture'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'profilePicture': profilePicture,
      'bio': bio,
    };
  }
}
