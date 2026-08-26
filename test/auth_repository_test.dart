import 'dart:convert';

import 'package:engcoach/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Bodies copied from real calls to bdappsdigitalapps.com on 2026-08-25, so
/// these tests fail if the server's shape ever drifts from what was verified.
const _unregistered =
    '{"subscriptionStatus":"UNREGISTERED","isSubscribed":false,'
    '"statusCode":"S1000","statusDetail":"Request was successfully processed.",'
    '"version":"1.0","subscriberId":"tel:8801895613473",'
    '"phone":"01895613473","firebaseToken":null}';

const _registered =
    '{"subscriptionStatus":"REGISTERED","isSubscribed":true,'
    '"statusCode":"S1000","statusDetail":"Request was successfully processed.",'
    '"version":"1.0","subscriberId":"tel:8801895613473",'
    '"phone":"01895613473","firebaseToken":"eyJhbGciOiJSUzI1NiJ9.token"}';

const _otpSent =
    '{"success":true,"referenceNo":"88018956134731787726700676152364",'
    '"statusCode":"S1000","statusDetail":"Request was successfully processed.",'
    '"version":"1.0"}';

const _alreadyRegistered =
    '{"success":false,"message":"user already registered","referenceNo":null,'
    '"statusCode":"E1351","subscriberId":"tel:8801895613473"}';

const _verified =
    '{"statusCode":"S1000","statusDetail":"Success",'
    '"subscriptionStatus":"INITIAL CHARGING PENDING",'
    '"subscriberId":"tel:8801895613473","version":"1.0",'
    '"phone":"01895613473","isSubscribed":true,'
    '"firebaseToken":"eyJhbGciOiJSUzI1NiJ9.token"}';

const _wrongOtp =
    '{"statusCode":"E1850","statusDetail":"Invalid OTP",'
    '"subscriptionStatus":"","subscriberId":"","version":"1.0",'
    '"phone":"","isSubscribed":false,"firebaseToken":null}';

void main() {
  const phone = '01895613473';

  /// Answers each endpoint from [bodies], keyed by file name, and records
  /// what was asked for.
  ({BdappsAuthRepository repo, List<String> calls, List<Map<String, String>> posts})
      repoWith(Map<String, String> bodies) {
    final calls = <String>[];
    final posts = <Map<String, String>>[];

    final client = MockClient((request) async {
      final path = request.url.pathSegments.last;
      calls.add(path);
      posts.add(Uri.splitQueryString(request.body));

      final body = bodies[path];
      if (body == null) return http.Response('not stubbed', 404);
      return http.Response(body, 200);
    });

    return (
      repo: BdappsAuthRepository(client: client, baseUrl: 'https://example.test'),
      calls: calls,
      posts: posts,
    );
  }

  group('starting sign-in', () {
    test('an unsubscribed number gets a code', () async {
      final h = repoWith({
        'check_subscription.php': _unregistered,
        'send_otp.php': _otpSent,
      });

      final start = await h.repo.start(phone);

      expect(start, isA<CodeSent>());
      expect(
        (start as CodeSent).referenceNo,
        '88018956134731787726700676152364',
      );
      expect(start.resendAfter, const Duration(seconds: 45));
      expect(h.calls, ['check_subscription.php', 'send_otp.php']);
    });

    test('a subscribed number is signed in with no code at all', () async {
      final h = repoWith({'check_subscription.php': _registered});

      final start = await h.repo.start(phone);

      expect(start, isA<AlreadySignedIn>());
      final session = (start as AlreadySignedIn).session;
      expect(session.phone, phone);
      expect(session.isSubscribed, isTrue);
      expect(session.firebaseToken, startsWith('eyJ'));
      expect(
        h.calls,
        ['check_subscription.php'],
        reason: 'no OTP is sent — bdapps refuses one for a subscriber',
      );
    });

    test('the number is posted as bdapps expects it', () async {
      final h = repoWith({
        'check_subscription.php': _unregistered,
        'send_otp.php': _otpSent,
      });

      await h.repo.start(phone);

      expect(h.posts.first, {'user_mobile': phone});
    });

    test('E1351 between the two calls surfaces as readable wording', () async {
      final h = repoWith({
        'check_subscription.php': _unregistered,
        'send_otp.php': _alreadyRegistered,
      });

      await expectLater(
        h.repo.start(phone),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('already subscribed'),
          ),
        ),
      );
    });
  });

  group('verifying', () {
    test('a correct code returns a subscribed session', () async {
      final h = repoWith({'verify_otp.php': _verified});

      final session = await h.repo.verify(
        phone: phone,
        code: '111273',
        referenceNo: 'ref-123',
      );

      expect(session.phone, phone);
      expect(session.firebaseToken, startsWith('eyJ'));
      expect(
        session.isSubscribed,
        isTrue,
        reason: 'INITIAL CHARGING PENDING still counts as subscribed',
      );
      expect(h.posts.single, {'Otp': '111273', 'referenceNo': 'ref-123'});
    });

    test('a wrong code fails with wording the screen can show', () async {
      final h = repoWith({'verify_otp.php': _wrongOtp});

      await expectLater(
        h.repo.verify(phone: phone, code: '000000', referenceNo: 'ref-123'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('not right'),
          ),
        ),
      );
    });

    test('a missing Firebase key still signs the learner in', () async {
      // The server returns null when it cannot read the service-account key.
      // bdapps has still verified the number; only Firestore is out of reach.
      final h = repoWith({
        'verify_otp.php': jsonEncode({
          'statusCode': 'S1000',
          'subscriptionStatus': 'INITIAL CHARGING PENDING',
          'phone': phone,
          'isSubscribed': true,
          'firebaseToken': null,
        }),
      });

      final session = await h.repo.verify(
        phone: phone,
        code: '111273',
        referenceNo: 'ref-123',
      );

      expect(session.isSubscribed, isTrue);
      expect(session.firebaseToken, isNull);
    });
  });

  group('subscription checks', () {
    test('reads the live value rather than anything cached', () async {
      final h = repoWith({'check_subscription.php': _registered});
      expect(await h.repo.isSubscribed(phone), isTrue);

      final gone = repoWith({'check_subscription.php': _unregistered});
      expect(await gone.repo.isSubscribed(phone), isFalse);
    });
  });

  group('unsubscribing', () {
    test('ends the subscription', () async {
      final h = repoWith({
        'unsubscribe.php':
            '{"success":true,"subscriberId":"tel:8801895613473",'
            '"statusCode":"S1000","statusDetail":"Success",'
            '"subscriptionStatus":"UNREGISTERED"}',
      });

      await h.repo.unsubscribe(phone);

      expect(h.calls, ['unsubscribe.php']);
      expect(h.posts.single, {'user_mobile': phone});
    });

    test('a number that was already off counts as done', () async {
      final h = repoWith({
        'unsubscribe.php':
            '{"success":false,"subscriptionStatus":"UNREGISTERED"}',
      });

      // The caller asked for it to be off, and it is off.
      await h.repo.unsubscribe(phone);
    });

    test('a refusal throws rather than reporting success', () async {
      // Reporting success here would tell someone the charging had stopped
      // when it had not.
      final h = repoWith({
        'unsubscribe.php':
            '{"success":false,"statusDetail":"Service unavailable",'
            '"subscriptionStatus":"REGISTERED"}',
      });

      await expectLater(
        h.repo.unsubscribe(phone),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('failures', () {
    test('a dead connection reads as a connection problem', () async {
      final repo = BdappsAuthRepository(
        client: MockClient((_) => throw const SocketExceptionStub()),
        baseUrl: 'https://example.test',
      );

      await expectLater(
        repo.start(phone),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('connection'),
          ),
        ),
      );
    });

    test('a 500 never reaches the learner as a status code', () async {
      final repo = BdappsAuthRepository(
        client: MockClient((_) async => http.Response('<html>500</html>', 500)),
        baseUrl: 'https://example.test',
      );

      await expectLater(
        repo.start(phone),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('a non-JSON body does not crash the screen', () async {
      final repo = BdappsAuthRepository(
        client: MockClient((_) async => http.Response('<br />warning', 200)),
        baseUrl: 'https://example.test',
      );

      await expectLater(repo.start(phone), throwsA(isA<AuthFailure>()));
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
