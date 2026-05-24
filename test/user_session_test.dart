import 'package:flutter_test/flutter_test.dart';
import 'package:club_connect_flutter/src/models/user_session.dart';

void main() {
  test('parses multi-role users and club memberships', () {
    final session = UserSession.fromJson({
      'id': 'user-1',
      'name': 'Santosh',
      'email': 'santosh.amish@walchandsangli.ac.in',
      'role': 'advisor',
      'roles': ['advisor', 'president', 'treasurer'],
      'clubId': 'club-a',
      'clubName': 'WCE ACM',
      'memberships': [
        {
          'clubId': 'club-a',
          'clubName': 'WCE ACM',
          'role': 'Advisor',
          'officerRole': 'advisor',
        },
        {
          'clubId': 'club-b',
          'clubName': 'WCE IEEE',
          'role': 'President',
          'boardType': 'main',
        },
      ],
      'likedClubs': ['club-x'],
    });

    expect(
      session.allRoles,
      containsAll(['advisor', 'president', 'treasurer']),
    );
    expect(session.hasRole('advisor'), isTrue);
    expect(session.hasAnyRole(['teacher', 'advisor']), isTrue);
    expect(session.hasAdminAccess, isFalse);
    expect(
      session.hasClubRole('club-a', ['advisor', 'club-secretary']),
      isTrue,
    );
    expect(
      session.hasClubRole('club-b', ['club-secretary', 'president']),
      isTrue,
    );
    expect(session.likedClubs, contains('club-x'));
  });
}
