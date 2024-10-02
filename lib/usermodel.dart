class Usermodel {
  final String username;
  final String password;
  final String email;

  Usermodel({
    required this.username,
    required this.password,
    required this.email,
  });
  factory Usermodel.fromJson(Map<String, dynamic> json) {
    return Usermodel(
      username: json['username'] as String,
      password: json['password'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'email': email,
    };
  }
}
