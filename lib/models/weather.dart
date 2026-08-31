// Weather models backed by the Open-Meteo API (free, no API key required).

/// WMO weather interpretation codes, collapsed into the handful of buckets
/// we actually render.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  heavyRain,
  thunderstorm,
  snow,
  unknown;

  static WeatherCondition fromWmoCode(int code) {
    return switch (code) {
      0 => WeatherCondition.clear,
      1 || 2 => WeatherCondition.partlyCloudy,
      3 => WeatherCondition.cloudy,
      45 || 48 => WeatherCondition.fog,
      51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
      61 || 63 || 80 || 81 => WeatherCondition.rain,
      65 || 66 || 67 || 82 => WeatherCondition.heavyRain,
      71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
      95 || 96 || 99 => WeatherCondition.thunderstorm,
      _ => WeatherCondition.unknown,
    };
  }

  String get label => switch (this) {
    WeatherCondition.clear => 'Clear',
    WeatherCondition.partlyCloudy => 'Partly Cloudy',
    WeatherCondition.cloudy => 'Cloudy',
    WeatherCondition.fog => 'Fog',
    WeatherCondition.drizzle => 'Drizzle',
    WeatherCondition.rain => 'Rain',
    WeatherCondition.heavyRain => 'Heavy Rain',
    WeatherCondition.thunderstorm => 'Thunderstorm',
    WeatherCondition.snow => 'Snow',
    WeatherCondition.unknown => 'Unknown',
  };

  /// True when this condition puts meaningful water into the soil.
  bool get isWet =>
      this == WeatherCondition.rain ||
      this == WeatherCondition.heavyRain ||
      this == WeatherCondition.thunderstorm ||
      this == WeatherCondition.drizzle;
}

class CurrentWeather {
  final double temperatureC;
  final double feelsLikeC;
  final double humidity;
  final double windKph;
  final double precipitationMm;
  final WeatherCondition condition;
  final bool isDay;
  final DateTime observedAt;

  const CurrentWeather({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windKph,
    required this.precipitationMm,
    required this.condition,
    required this.isDay,
    required this.observedAt,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperatureC: (json['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLikeC: (json['apparent_temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      windKph: (json['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      precipitationMm: (json['precipitation'] as num?)?.toDouble() ?? 0,
      condition: WeatherCondition.fromWmoCode(
        (json['weather_code'] as num?)?.toInt() ?? -1,
      ),
      isDay: ((json['is_day'] as num?)?.toInt() ?? 1) == 1,
      observedAt:
          DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperatureC;
  final double precipitationMm;
  final int precipitationProbability;
  final WeatherCondition condition;

  const HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.precipitationMm,
    required this.precipitationProbability,
    required this.condition,
  });
}

class DailyForecast {
  final DateTime date;
  final double maxTempC;
  final double minTempC;
  final double precipitationMm;
  final int precipitationProbability;
  final double windMaxKph;

  /// Reference evapotranspiration in mm — how much water the crop+soil will
  /// lose to the atmosphere that day. Drives the irrigation advisor.
  final double et0Mm;
  final WeatherCondition condition;

  const DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.precipitationMm,
    required this.precipitationProbability,
    required this.windMaxKph,
    required this.et0Mm,
    required this.condition,
  });
}

class WeatherReport {
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final String locationName;
  final DateTime fetchedAt;

  const WeatherReport({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.locationName,
    required this.fetchedAt,
  });

  /// Total rain expected over the next [hours] hours.
  double rainfallInNextHours(int hours) {
    final cutoff = DateTime.now().add(Duration(hours: hours));
    return hourly
        .where((h) => h.time.isAfter(DateTime.now()) && h.time.isBefore(cutoff))
        .fold(0.0, (sum, h) => sum + h.precipitationMm);
  }

  /// Highest chance of rain in the next [hours] hours, as a percentage.
  int peakRainChanceInNextHours(int hours) {
    final cutoff = DateTime.now().add(Duration(hours: hours));
    final window = hourly.where(
      (h) => h.time.isAfter(DateTime.now()) && h.time.isBefore(cutoff),
    );
    if (window.isEmpty) return 0;
    return window
        .map((h) => h.precipitationProbability)
        .reduce((a, b) => a > b ? a : b);
  }

  /// The first upcoming hour with a meaningful chance of rain, if any.
  HourlyForecast? get nextRainHour {
    final now = DateTime.now();
    for (final h in hourly) {
      if (h.time.isAfter(now) &&
          h.precipitationProbability >= 50 &&
          h.precipitationMm > 0.2) {
        return h;
      }
    }
    return null;
  }

  double get totalRainfallNext7Days =>
      daily.fold(0.0, (sum, d) => sum + d.precipitationMm);

  double get averageMaxTempNext7Days => daily.isEmpty
      ? current.temperatureC
      : daily.fold(0.0, (sum, d) => sum + d.maxTempC) / daily.length;
}

class FarmLocation {
  final double latitude;
  final double longitude;
  final String name;

  const FarmLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  /// Kumasi, Ghana — used until the user grants location access or sets
  /// coordinates manually in Settings.
  static const FarmLocation fallback = FarmLocation(
    latitude: 6.6885,
    longitude: -1.6244,
    name: 'Kumasi, Ghana',
  );

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'name': name,
  };

  factory FarmLocation.fromJson(Map<String, dynamic> json) => FarmLocation(
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    name: json['name'] as String,
  );
}
