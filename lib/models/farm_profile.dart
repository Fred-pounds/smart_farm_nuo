import 'weather.dart';

/// Who the farm is: its name, where it sits, and how big it is.
///
/// Separate from [FarmData], which is what the controller reports moment to
/// moment. This is the part the farmer owns and the app remembers.
///
/// The name matters more than it looks. Open-Meteo has no reverse-geocoding
/// endpoint, so coordinates cannot be turned into a place name reliably — the
/// app used to print `6.667, -1.552` in the header, which tells a farmer
/// nothing about their own farm. Letting them name it is both simpler and
/// more useful than any lookup.
class FarmProfile {
  final String name;
  final FarmLocation location;

  /// Field size in square metres. Drives the litres-saved estimates.
  final double areaSqm;

  /// True when the coordinates came from GPS rather than a manual choice, so
  /// Settings can offer to re-acquire them.
  final bool locationFromGps;

  const FarmProfile({
    required this.name,
    required this.location,
    this.areaSqm = 100,
    this.locationFromGps = false,
  });

  /// Whether the farmer has actually set this up, as opposed to the app
  /// guessing. Drives first-run onboarding.
  bool get isConfigured => name.trim().isNotEmpty;

  /// Area rendered the way a farmer would say it.
  String get areaLabel {
    if (areaSqm >= 10000) {
      final ha = areaSqm / 10000;
      return '${ha.toStringAsFixed(ha % 1 == 0 ? 0 : 1)} ha';
    }
    return '${areaSqm.round()} m²';
  }

  FarmProfile copyWith({
    String? name,
    FarmLocation? location,
    double? areaSqm,
    bool? locationFromGps,
  }) {
    return FarmProfile(
      name: name ?? this.name,
      location: location ?? this.location,
      areaSqm: areaSqm ?? this.areaSqm,
      locationFromGps: locationFromGps ?? this.locationFromGps,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location.toJson(),
    'areaSqm': areaSqm,
    'locationFromGps': locationFromGps,
  };

  factory FarmProfile.fromJson(Map<String, dynamic> json) => FarmProfile(
    name: (json['name'] as String?) ?? '',
    location: FarmLocation.fromJson(
      (json['location'] as Map).cast<String, dynamic>(),
    ),
    areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 100,
    locationFromGps: (json['locationFromGps'] as bool?) ?? false,
  );

  /// The state before setup: unnamed, pointed at the default location.
  static const FarmProfile unset = FarmProfile(
    name: '',
    location: FarmLocation.fallback,
  );
}
