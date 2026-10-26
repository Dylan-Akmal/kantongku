import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/features/groups/group.dart';
import 'package:kantongku_mobile/features/groups/group_utils.dart';

void main() {
  test('Group.fromJson membaca daftar grup tanpa anggota', () {
    final group = Group.fromJson({
      'id': 4,
      'name': 'Trip Bali',
      'invite_code': 'YU92EY7M',
      'my_role': 'owner',
      'owner': {'id': 1, 'name': 'Ujiii123'},
      'member_count': 2,
      'created_at': '2026-10-23T06:31:00.000000Z',
    });

    expect(group.name, 'Trip Bali');
    expect(group.inviteCode, 'YU92EY7M');
    expect(group.isOwner, isTrue);
    expect(group.memberCount, 2);
    expect(group.ownerName, 'Ujiii123');
    expect(group.members, isEmpty);
  });

  test('Group.fromJson membaca detail grup beserta anggota', () {
    final group = Group.fromJson({
      'id': 4,
      'name': 'Trip Bali',
      'invite_code': 'YU92EY7M',
      'my_role': 'member',
      'owner': {'id': 1, 'name': 'Ujiii123'},
      'member_count': 2,
      'members': [
        {'id': 1, 'name': 'Ujiii123', 'role': 'owner', 'joined_at': '2026-10-23 13:31:00'},
        {'id': 2, 'name': 'Teman Uji', 'role': 'member', 'joined_at': '2026-10-24 09:00:00'},
      ],
    });

    expect(group.isOwner, isFalse);
    expect(group.members, hasLength(2));
    expect(group.members.first.isOwner, isTrue);
    expect(group.members.last.joinedDate, '2026-10-24');
  });

  test('initials mengambil huruf awal dari dua kata pertama', () {
    expect(initials('Dylan Akmal'), 'DA');
    expect(initials('trip bali 2026'), 'TB');
    expect(initials('Kantongku'), 'K');
    expect(initials(''), '?');
  });
}