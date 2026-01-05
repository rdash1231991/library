import 'package:flutter_test/flutter_test.dart';

import 'package:habit_challenge_tracker/core/utils/date_time_utils.dart';

void main() {
  test('ISO date roundtrip', () {
    final d = DateTime(2026, 1, 5);
    final iso = d.toIsoDate();
    expect(parseIsoDate(iso), d.toDateOnly());
  });
}
