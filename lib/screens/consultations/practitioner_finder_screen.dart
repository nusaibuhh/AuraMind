import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';

class PractitionerFinderScreen extends StatefulWidget {
  const PractitionerFinderScreen({super.key});

  @override
  State<PractitionerFinderScreen> createState() =>
      _PractitionerFinderScreenState();
}

class _PractitionerFinderScreenState extends State<PractitionerFinderScreen> {
  final MapController _mapController = MapController();
  final List<_NearbyPlace> _places = [];

  Position? _position;
  bool _loading = false;
  String? _error;
  double _radiusKm = 5;

  static const _bangladeshDirectory =
      'https://doctorappointmentbd.com/specialists/psychiatrist/';

  Future<void> _findNearby() async {
    setState(() {
      _loading = true;
      _error = null;
      _places.clear();
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on Location Services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in your device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/practitioners/nearby-osm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'radius_meters': (_radiusKm * 1000).round(),
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(
          body is Map && body['detail'] is String
              ? body['detail']
              : 'Could not search nearby practitioners.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (decoded['places'] as List? ?? [])
          .map((item) => _NearbyPlace.fromJson(item as Map<String, dynamic>))
          .where((item) => item.latitude != null && item.longitude != null)
          .toList();

      if (!mounted) return;
      setState(() {
        _position = position;
        _places.addAll(items);
        _loading = false;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openBangladeshDirectory() async {
    final launched = await launchUrl(
      Uri.parse(_bangladeshDirectory),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Bangladesh directory.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _position == null
        ? const LatLng(23.8103, 90.4125)
        : LatLng(_position!.latitude, _position!.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geolocation Practitioner Finder'),
        actions: [
          TextButton.icon(
            onPressed: _openBangladeshDirectory,
            icon: const Icon(Icons.public_rounded, size: 18),
            label: const Text('Practitioners of Bangladesh'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Find mental-health locations near you',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Uses your device location and OpenStreetMap data. No Google API key or billing account is required.',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Search radius'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _radiusKm,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '${_radiusKm.round()} km',
                            onChanged: _loading
                                ? null
                                : (value) => setState(() => _radiusKm = value),
                          ),
                        ),
                        Text('${_radiusKm.round()} km'),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _findNearby,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          _loading ? 'Finding nearby locations…' : 'Find Near Me',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Could not complete the nearby search'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: _findNearby,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    minZoom: 3,
                    maxZoom: 19,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.auramind.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_position != null)
                          Marker(
                            point: center,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: Colors.blue,
                              size: 34,
                            ),
                          ),
                        ..._places.map(
                          (place) => Marker(
                            point: LatLng(place.latitude!, place.longitude!),
                            width: 48,
                            height: 48,
                            child: GestureDetector(
                              onTap: () => _showPlace(place),
                              child: const Icon(
                                Icons.local_hospital_rounded,
                                color: Colors.red,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://www.openstreetmap.org/copyright'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_places.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${_places.length} nearby mental-health location${_places.length == 1 ? '' : 's'} found. Tap a marker for details.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlace(_NearbyPlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (place.type.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(place.type),
              ],
              if (place.address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(place.address),
              ],
              const SizedBox(height: 12),
              const Text(
                'Location data comes from OpenStreetMap and may not indicate medical verification. Use the Bangladesh directory above or an AuraMind admin-approved practitioner for verified referral information.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyPlace {
  const _NearbyPlace({
    required this.name,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String type;
  final String address;
  final double? latitude;
  final double? longitude;

  factory _NearbyPlace.fromJson(Map<String, dynamic> json) {
    return _NearbyPlace(
      name: json['name'] as String? ?? 'Mental-health location',
      type: json['type'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
