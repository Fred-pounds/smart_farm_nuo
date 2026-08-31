import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farm_profile.dart';
import '../models/weather.dart';
import '../providers/farm_profile_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/theme.dart';

/// Where a farm gets named and placed on the map.
///
/// Runs once on first launch and stays reachable from Settings. Three fields,
/// in the order a farmer would answer them: what it is called, where it is,
/// how big it is.
///
/// Location is the only one that genuinely matters to the software — it is
/// what the forecast is fetched for, and therefore what decides whether the
/// pump holds off for rain.
class FarmSetupScreen extends StatefulWidget {
  /// True on first launch, when there is nothing to go back to.
  final bool isOnboarding;

  const FarmSetupScreen({super.key, this.isOnboarding = false});

  @override
  State<FarmSetupScreen> createState() => _FarmSetupScreenState();
}

class _FarmSetupScreenState extends State<FarmSetupScreen> {
  late final TextEditingController _name;
  late FarmLocation _location;
  late double _areaSqm;
  bool _fromGps = false;

  bool _locating = false;
  String? _locationNote;

  @override
  void initState() {
    super.initState();
    final profile = context.read<FarmProfileProvider>().profile;
    _name = TextEditingController(text: profile.name);
    _location = profile.location;
    _areaSqm = profile.areaSqm;
    _fromGps = profile.locationFromGps;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });

    final found = await context.read<FarmProfileProvider>().detectLocation();
    if (!mounted) return;

    setState(() {
      _locating = false;
      if (found == null) {
        _locationNote =
            'Could not get a location fix. Check that location is turned on '
            'and permission is granted, or search for the nearest town '
            'instead.';
      } else {
        _location = found;
        _fromGps = true;
      }
    });
  }

  Future<void> _searchForPlace() async {
    final picked = await showModalBottomSheet<FarmLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PlaceSearchSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = picked;
      _fromGps = false;
      _locationNote = null;
    });
  }

  Future<void> _save() async {
    final profiles = context.read<FarmProfileProvider>();
    await profiles.save(
      FarmProfile(
        name: _name.text.trim(),
        location: _location,
        areaSqm: _areaSqm,
        locationFromGps: _fromGps,
      ),
    );
    if (!mounted) return;

    // The forecast is fetched for the farm's coordinates, so moving the farm
    // has to move the weather with it.
    await context.read<WeatherProvider>().setLocation(_location);
    if (!mounted) return;

    if (widget.isOnboarding) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return GlassScaffold(
      title: widget.isOnboarding ? 'Set up your farm' : 'Farm details',
      subtitle: widget.isOnboarding
          ? 'Takes about a minute'
          : 'Name, location and size',
      insideShell: false,
      leading: widget.isOnboarding
          ? const SizedBox(width: Tokens.space3)
          : null,
      builder: (context, contentPadding) => ListView(
        padding: contentPadding,
        children: [
          if (widget.isOnboarding) ...[
            Text(
              'The app needs to know where your farm is before it can tell '
              'the controller whether rain is coming.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Tokens.space5),
          ],

          Section(
            title: 'Name',
            children: [
              Panel(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Nuo Farm',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space5),

          Section(
            title: 'Location',
            description:
                'Used to fetch your forecast. The controller holds irrigation '
                'back when rain is likely here.',
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 18,
                          color: colors.growth,
                        ),
                        const SizedBox(width: Tokens.space2),
                        Expanded(
                          child: Text(
                            _location.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Tokens.space1),
                    Text(
                      '${_location.latitude.toStringAsFixed(3)}, '
                      '${_location.longitude.toStringAsFixed(3)}'
                      '${_fromGps ? ' · from GPS' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.inkTertiary,
                      ),
                    ),
                    const SizedBox(height: Tokens.space4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: const Text('Use GPS'),
                          ),
                        ),
                        const SizedBox(width: Tokens.space3),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _searchForPlace,
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Search'),
                          ),
                        ),
                      ],
                    ),
                    if (_locationNote != null) ...[
                      const SizedBox(height: Tokens.space3),
                      Text(
                        _locationNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.sun,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space5),

          Section(
            title: 'Field size',
            description: 'Used to estimate how much water a rain shower saves.',
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _areaLabel,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    Slider(
                      value: _areaSqm.clamp(50, 20000),
                      min: 50,
                      max: 20000,
                      onChanged: (v) => setState(() => _areaSqm = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space6),

          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              widget.isOnboarding ? 'Start monitoring' : 'Save changes',
            ),
          ),
          if (!_canSave) ...[
            const SizedBox(height: Tokens.space3),
            Text(
              'Give your farm a name to continue.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }

  String get _areaLabel {
    if (_areaSqm >= 10000) {
      final ha = _areaSqm / 10000;
      return '${ha.toStringAsFixed(1)} ha';
    }
    return '${_areaSqm.round()} m²';
  }
}

/// Place search, by name. The only way to set a location without GPS.
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet();

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _query = TextEditingController();
  List<FarmLocation> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;

    setState(() => _searching = true);
    final found = await context.read<FarmProfileProvider>().searchPlaces(text);
    if (!mounted) return;
    setState(() {
      _results = found;
      _searching = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: GlassSurface(
        strong: true,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Tokens.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find your farm',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Tokens.space2),
              Text(
                'Search for the nearest town or village.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
              ),
              const SizedBox(height: Tokens.space4),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  hintText: 'e.g. Kumasi',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: _run,
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space4),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Tokens.space6),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searched && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.space5),
                  child: Text(
                    'Nothing found. Try a larger nearby town, or use GPS.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Tokens.space2),
                    itemBuilder: (context, i) {
                      final place = _results[i];
                      return Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space4,
                          vertical: Tokens.space3,
                        ),
                        onTap: () => Navigator.of(context).pop(place),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: colors.inkTertiary,
                            ),
                            const SizedBox(width: Tokens.space3),
                            Expanded(
                              child: Text(
                                place.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: Tokens.space3),
            ],
          ),
        ),
      ),
    );
  }
}
