class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.role,
    this.joinedAt,
  });

  final int id;
  final String name;
  final String role;
  final String? joinedAt;

  bool get isOwner => role == 'owner';

  /// "2026-10-23 14:05:00" menjadi "2026-10-23".
  String? get joinedDate =>
      (joinedAt != null && joinedAt!.length >= 10) ? joinedAt!.substring(0, 10) : null;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      joinedAt: json['joined_at'] as String?,
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.myRole,
    required this.memberCount,
    required this.ownerName,
    this.members = const [],
  });

  final int id;
  final String name;
  final String inviteCode;
  final String myRole;
  final int memberCount;
  final String ownerName;
  final List<GroupMember> members;

  bool get isOwner => myRole == 'owner';

  factory Group.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;

    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      myRole: json['my_role'] as String,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      ownerName: (owner?['name'] as String?) ?? '',
      members: ((json['members'] as List?) ?? const [])
          .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}