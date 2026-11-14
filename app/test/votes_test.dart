import 'package:flutter_test/flutter_test.dart';
import 'package:toni/core/models.dart';
import 'package:toni/ui/votes.dart';

Vote _vote(String id, String status, DateTime resolvedAt, {String reason = 'Abwasch'}) => Vote(
      id: id, personId: 'p1', periodId: 'm', reason: reason, createdBy: null,
      createdAt: resolvedAt.subtract(const Duration(hours: 1)), status: status, resolvedAt: resolvedAt, ballots: const {},
    );

void main() {
  final strike = Strike(id: 's', personId: 'p1', periodId: 'm', reason: 'Abwasch', createdAt: DateTime.utc(2026, 11, 11, 10), source: 'abstimmung');

  test('a strike finds the accepted vote that created it', () {
    final votes = [
      _vote('older', 'angenommen', DateTime.utc(2026, 11, 2)),
      _vote('rejected', 'abgelehnt', DateTime.utc(2026, 11, 11, 10)),
      _vote('other reason', 'angenommen', DateTime.utc(2026, 11, 11, 10), reason: 'Müll'),
      _vote('it', 'angenommen', DateTime.utc(2026, 11, 11, 10)),
    ];
    expect(voteForStrike(strike, votes)?.id, 'it');
    expect(voteForStrike(strike, votes.take(3).toList())?.id, 'older');
    expect(voteForStrike(strike, [votes[1], votes[2]]), isNull);
  });
}
