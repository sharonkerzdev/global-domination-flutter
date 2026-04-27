import 'dart:convert';

Map<String, dynamic> _inertAchievement(String id) => {
  'id': id,
  'name': 'Fixture inert',
  'conditionType': 'countriesUnlockedAtLeast',
  'conditionParams': {'count': 999999},
  'rewardType': 'influenceMultiplier',
  'rewardValue': '0',
};

/// 27 achievements that never fire in normal fixtures (999999 countries) and
/// contribute no multiplier if earned (`rewardValue` 0).
String trivial27AchievementsJson() => jsonEncode(
  List.generate(27, (i) => _inertAchievement('ach_fixture_inert_$i')),
);

/// Pads [extras] with inert achievements to length 27.
String achievementsJson27(List<Map<String, dynamic>> extras) {
  if (extras.length > 27) {
    throw ArgumentError.value(extras.length, 'extras.length', 'must be <= 27');
  }
  var pad = 0;
  final out = [...extras];
  while (out.length < 27) {
    out.add(_inertAchievement('ach_fixture_pad_${pad++}'));
  }
  return jsonEncode(out);
}
