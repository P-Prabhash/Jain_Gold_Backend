class AdminModel {
  final int id;
  final String username;
  final String fullName;
  final String? employeeId;
  final String? mobile;
  final String? email;
  final String? department;
  final String? designation;
  final String role;
  final String status;
  final int permissionsConfigured;
  final String? createdAt;
  final String? updatedAt;

  AdminModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.employeeId,
    this.mobile,
    this.email,
    this.department,
    this.designation,
    required this.role,
    required this.status,
    this.permissionsConfigured = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminModel(
      id: _toInt(json['id']),
      username: _toString(json['username']),
      fullName: _toString(
        json['full_name'] ?? json['fullName'],
      ),
      employeeId: _nullableString(
        json['employee_id'] ??
            json['employeeId'],
      ),
      mobile: _nullableString(
        json['mobile'],
      ),
      email: _nullableString(
        json['email'],
      ),
      department: _nullableString(
        json['department'],
      ),
      designation: _nullableString(
        json['designation'],
      ),
      role: _toString(
        json['role'],
      ),
      status: _toString(
        json['status'],
      ),
      permissionsConfigured: _toInt(
        json['permissions_configured'] ??
            json['permissionsConfigured'],
      ),
      createdAt: _nullableString(
        json['created_at'] ??
            json['createdAt'],
      ),
      updatedAt: _nullableString(
        json['updated_at'] ??
            json['updatedAt'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'employee_id': employeeId,
      'mobile': mobile,
      'email': email,
      'department': department,
      'designation': designation,
      'role': role,
      'status': status,
      'permissions_configured':
          permissionsConfigured,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isActive {
    return status.toUpperCase() == 'ACTIVE';
  }

  bool get isAdmin {
    return role.toUpperCase() == 'ADMIN';
  }

  bool get hasCustomPermissions {
    return permissionsConfigured == 1;
  }

  AdminModel copyWith({
    int? id,
    String? username,
    String? fullName,
    String? employeeId,
    String? mobile,
    String? email,
    String? department,
    String? designation,
    String? role,
    String? status,
    int? permissionsConfigured,
    String? createdAt,
    String? updatedAt,
  }) {
    return AdminModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      employeeId: employeeId ?? this.employeeId,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      status: status ?? this.status,
      permissionsConfigured:
          permissionsConfigured ??
              this.permissionsConfigured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static String _toString(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final valueString =
        value.toString().trim();

    return valueString.isEmpty
        ? null
        : valueString;
  }
}