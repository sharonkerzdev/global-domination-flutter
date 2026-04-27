import 'dart:convert';

/// Deterministic 7-day row data for [ContentRegistry.fromJsonStrings] fixtures:
/// influence `1…7`, intel `10…70` (per Story 5-4 reducer tests).
String testDailyRewardsJson() => jsonEncode([
  for (var d = 1; d <= 7; d++)
    {'day': d, 'influenceReward': '$d', 'intelReward': '${d * 10}'},
]);
