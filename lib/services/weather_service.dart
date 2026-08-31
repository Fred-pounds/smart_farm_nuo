import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Open-Meteo client. The forecast API is free for non-commercial use and
/// needs no API key, which keeps the app zero-config for the user.
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const _forecastHost = 'api.open-meteo.com';
  static const _geocodingHost = 'geocoding-api.open-meteo.com';

  final _client = http.Client();

  Future<WeatherReport> fetch(FarmLocation location) async {
    final uri = Uri.https(_forecastHost, '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'precipitation,weather_code,wind_speed_10m,is_day',
      'hourly':
          'temperature_2m,precipitation,precipitation_probability,'
          'weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_sum,precipitation_probability_max,'
          'wind_speed_10m_max,et0_fao_evapotranspiration',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Weather service returned ${response.statusCode}. Check your connection.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return WeatherReport(
      current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
      hourly: _parseHourly(json['hourly'] as Map<String, dynamic>?),
      daily: _parseDaily(json['daily'] as Map<String, dynamic>?),
      locationName: location.name,
      fetchedAt: DateTime.now(),
    );
  }

  List<HourlyForecast> _parseHourly(Map<String, dynamic>? hourly) {
    if (hourly == null) return const [];

    final times = (hourly['time'] as List?) ?? const [];
    final temps = (hourly['temperature_2m'] as List?) ?? const [];
    final precip = (hourly['precipitation'] as List?) ?? const [];
    final probs = (hourly['precipitation_probability'] as List?) ?? const [];
    final codes = (hourly['weather_code'] as List?) ?? const [];

    return List.generate(times.length, (i) {
      return HourlyForecast(
        time: DateTime.tryParse(times[i] as String) ?? DateTime.now(),
        temperatureC: _numAt(temps, i),
        precipitationMm: _numAt(precip, i),
        precipitationProbability: _numAt(probs, i).round(),
        condition: WeatherCondition.fromWmoCode(_numAt(codes, i).toInt()),
      );
    });
  }

  List<DailyForecast> _parseDaily(Map<String, dynamic>? daily) {
    if (daily == null) return const [];

    final dates = (daily['time'] as List?) ?? const [];
    final maxT = (daily['temperature_2m_max'] as List?) ?? const [];
    final minT = (daily['temperature_2m_min'] as List?) ?? const [];
    final rain = (daily['precipitation_sum'] as List?) ?? const [];
    final prob = (daily['precipitation_probability_max'] as List?) ?? const [];
    final wind = (daily['wind_speed_10m_max'] as List?) ?? const [];
    final et0 = (daily['et0_fao_evapotranspiration'] as List?) ?? const [];
    final codes = (daily['weather_code'] as List?) ?? const [];

    return List.generate(dates.length, (i) {
      return DailyForecast(
        date: DateTime.tryParse(dates[i] as String) ?? DateTime.now(),
        maxTempC: _numAt(maxT, i),
        minTempC: _numAt(minT, i),
        precipitationMm: _numAt(rain, i),
        precipitationProbability: _numAt(prob, i).round(),
        windMaxKph: _numAt(wind, i),
        et0Mm: _numAt(et0, i),
        condition: WeatherCondition.fromWmoCode(_numAt(codes, i).toInt()),
      );
    });
  }

  /// Looks up coordinates for a place name, so the user can set their farm
  /// location without granting GPS permission.
  Future<List<FarmLocation>> searchPlaces(String query) async {
    if (query.trim().length < 2) return const [];

    final uri = Uri.https(_geocodingHost, '/v1/search', {
      'name': query.trim(),
      'count': '8',
      'language': 'en',
      'format': 'json',
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? const [];

    return results.map((raw) {
      final r = raw as Map<String, dynamic>;
      final parts = [
        r['name'] as String?,
        r['admin1'] as String?,
        r['country'] as String?,
      ].whereType<String>().where((s) => s.isNotEmpty);

      return FarmLocation(
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
        name: parts.join(', '),
      );
    }).toList();
  }

  /// Turns coordinates into the nearest place name, for the header label.
  /// Falls back to formatted coordinates when nothing is close by.
  Future<String> describeCoordinates(double lat, double lon) async {
    try {
      final uri = Uri.https(_geocodingHost, '/v1/search', {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'count': '1',
        'language': 'en',
        'format': 'json',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (json['results'] as List?) ?? const [];
        if (results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final name = r['name'] as String?;
          final country = r['country'] as String?;
          if (name != null) {
            return country == null ? name : '$name, $country';
          }
        }
      }
    } catch (_) {
      // Naming is cosmetic — fall through to coordinates.
    }
    return '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
  }

  double _numAt(List list, int i) {
    if (i >= list.length) return 0;
    final v = list[i];
    return v is num ? v.toDouble() : 0;
  }
}
