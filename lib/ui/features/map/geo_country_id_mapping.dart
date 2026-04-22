import 'package:logging/logging.dart';

final _log = Logger('GeoJsonParser');

/// Maps GeoJSON `name` property values to game [CountryId] string values.
///
/// Derivation rule: lowercase, replace spaces with underscores, strip periods.
/// Special cases per story spec: Dem. Rep. Congo → dr_congo,
/// United States of America → united_states, United Arab Emirates → uae,
/// United Kingdom → united_kingdom, South Korea → south_korea,
/// Papua New Guinea → papua_new_guinea, New Zealand → new_zealand.
const Map<String, String> geoJsonNameToCountryIdMap = {
  // Africa (19)
  'Algeria': 'algeria',
  'Angola': 'angola',
  'Cameroon': 'cameroon',
  'Chad': 'chad',
  'Dem. Rep. Congo': 'dr_congo',
  'Egypt': 'egypt',
  'Ethiopia': 'ethiopia',
  'Kenya': 'kenya',
  'Libya': 'libya',
  'Madagascar': 'madagascar',
  'Morocco': 'morocco',
  'Namibia': 'namibia',
  'Niger': 'niger',
  'Nigeria': 'nigeria',
  'Somalia': 'somalia',
  'South Africa': 'south_africa',
  'Sudan': 'sudan',
  'Tanzania': 'tanzania',
  'Zimbabwe': 'zimbabwe',
  // Europe (19)
  'Bulgaria': 'bulgaria',
  'Denmark': 'denmark',
  'Finland': 'finland',
  'France': 'france',
  'Germany': 'germany',
  'Greece': 'greece',
  'Hungary': 'hungary',
  'Ireland': 'ireland',
  'Italy': 'italy',
  'Netherlands': 'netherlands',
  'Norway': 'norway',
  'Poland': 'poland',
  'Portugal': 'portugal',
  'Romania': 'romania',
  'Spain': 'spain',
  'Sweden': 'sweden',
  'Switzerland': 'switzerland',
  'Ukraine': 'ukraine',
  'United Kingdom': 'united_kingdom',
  // Middle East (10)
  'Iran': 'iran',
  'Iraq': 'iraq',
  'Israel': 'israel',
  'Oman': 'oman',
  'Qatar': 'qatar',
  'Saudi Arabia': 'saudi_arabia',
  'Syria': 'syria',
  'Turkey': 'turkey',
  'United Arab Emirates': 'uae',
  'Yemen': 'yemen',
  // Asia (16)
  'Afghanistan': 'afghanistan',
  'Bangladesh': 'bangladesh',
  'China': 'china',
  'India': 'india',
  'Indonesia': 'indonesia',
  'Japan': 'japan',
  'Kazakhstan': 'kazakhstan',
  'Malaysia': 'malaysia',
  'Mongolia': 'mongolia',
  'Myanmar': 'myanmar',
  'Pakistan': 'pakistan',
  'Philippines': 'philippines',
  'Russia': 'russia',
  'South Korea': 'south_korea',
  'Thailand': 'thailand',
  'Vietnam': 'vietnam',
  // South America (8)
  'Argentina': 'argentina',
  'Bolivia': 'bolivia',
  'Brazil': 'brazil',
  'Chile': 'chile',
  'Colombia': 'colombia',
  'Ecuador': 'ecuador',
  'Peru': 'peru',
  'Venezuela': 'venezuela',
  // North America (4)
  'Canada': 'canada',
  'Cuba': 'cuba',
  'Mexico': 'mexico',
  'United States of America': 'united_states',
  // Oceania (3)
  'Australia': 'australia',
  'New Zealand': 'new_zealand',
  'Papua New Guinea': 'papua_new_guinea',
};

/// Maps GeoJSON `name` property values to game continent ID strings.
/// Uses the GDD's 7-continent breakdown: Africa (19), Europe (19),
/// Middle East (10), Asia (16), South America (8), North America (4),
/// Oceania (3).
const Map<String, String> geoJsonNameToContinentIdMap = {
  // Africa
  'Algeria': 'africa',
  'Angola': 'africa',
  'Cameroon': 'africa',
  'Chad': 'africa',
  'Dem. Rep. Congo': 'africa',
  'Egypt': 'africa',
  'Ethiopia': 'africa',
  'Kenya': 'africa',
  'Libya': 'africa',
  'Madagascar': 'africa',
  'Morocco': 'africa',
  'Namibia': 'africa',
  'Niger': 'africa',
  'Nigeria': 'africa',
  'Somalia': 'africa',
  'South Africa': 'africa',
  'Sudan': 'africa',
  'Tanzania': 'africa',
  'Zimbabwe': 'africa',
  // Europe
  'Bulgaria': 'europe',
  'Denmark': 'europe',
  'Finland': 'europe',
  'France': 'europe',
  'Germany': 'europe',
  'Greece': 'europe',
  'Hungary': 'europe',
  'Ireland': 'europe',
  'Italy': 'europe',
  'Netherlands': 'europe',
  'Norway': 'europe',
  'Poland': 'europe',
  'Portugal': 'europe',
  'Romania': 'europe',
  'Spain': 'europe',
  'Sweden': 'europe',
  'Switzerland': 'europe',
  'Ukraine': 'europe',
  'United Kingdom': 'europe',
  // Middle East
  'Iran': 'middle_east',
  'Iraq': 'middle_east',
  'Israel': 'middle_east',
  'Oman': 'middle_east',
  'Qatar': 'middle_east',
  'Saudi Arabia': 'middle_east',
  'Syria': 'middle_east',
  'Turkey': 'middle_east',
  'United Arab Emirates': 'middle_east',
  'Yemen': 'middle_east',
  // Asia
  'Afghanistan': 'asia',
  'Bangladesh': 'asia',
  'China': 'asia',
  'India': 'asia',
  'Indonesia': 'asia',
  'Japan': 'asia',
  'Kazakhstan': 'asia',
  'Malaysia': 'asia',
  'Mongolia': 'asia',
  'Myanmar': 'asia',
  'Pakistan': 'asia',
  'Philippines': 'asia',
  'Russia': 'asia',
  'South Korea': 'asia',
  'Thailand': 'asia',
  'Vietnam': 'asia',
  // South America
  'Argentina': 'south_america',
  'Bolivia': 'south_america',
  'Brazil': 'south_america',
  'Chile': 'south_america',
  'Colombia': 'south_america',
  'Ecuador': 'south_america',
  'Peru': 'south_america',
  'Venezuela': 'south_america',
  // North America
  'Canada': 'north_america',
  'Cuba': 'north_america',
  'Mexico': 'north_america',
  'United States of America': 'north_america',
  // Oceania
  'Australia': 'oceania',
  'New Zealand': 'oceania',
  'Papua New Guinea': 'oceania',
};

/// Returns the game [CountryId] string for a GeoJSON name, or `null` if
/// the name is not recognised. Logs a warning for unmapped names.
String? geoJsonNameToCountryId(String geoJsonName) {
  final id = geoJsonNameToCountryIdMap[geoJsonName];
  if (id == null) {
    _log.warning('No CountryId mapping for GeoJSON name: "$geoJsonName"');
  }
  return id;
}

/// Returns the game continent ID string for a GeoJSON name, or `null` if
/// the name is not recognised. Logs a warning for unmapped names.
String? geoJsonNameToContinentId(String geoJsonName) {
  final id = geoJsonNameToContinentIdMap[geoJsonName];
  if (id == null) {
    _log.warning('No ContinentId mapping for GeoJSON name: "$geoJsonName"');
  }
  return id;
}
