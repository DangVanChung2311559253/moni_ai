class UserModel {
  final int? id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;

  const UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'created_at': createdAt.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'] as int?,
    name: map['name'] as String,
    email: map['email'] as String,
    password: map['password'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    DateTime? createdAt,
  }) => UserModel(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    password: password ?? this.password,
    createdAt: createdAt ?? this.createdAt,
  );
}
