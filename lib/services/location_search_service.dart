import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as native_geo;
import 'package:http/http.dart' as http;

class SearchResult {
	final String name;
	final String address;
	final double latitude;
	final double longitude;

	const SearchResult({
		required this.name,
		required this.address,
		required this.latitude,
		required this.longitude,
	});

	factory SearchResult.fromGoogle(Map<String, dynamic> json) {
		final geometry = json['geometry']?['location'] ?? {};
		return SearchResult(
			name: json['formatted_address']?.split(',')?.first?.trim() ??
					'Ubicación encontrada',
			address: json['formatted_address'] ?? '',
			latitude: (geometry['lat'] as num?)?.toDouble() ?? 0.0,
			longitude: (geometry['lng'] as num?)?.toDouble() ?? 0.0,
		);
	}

	factory SearchResult.fromNominatim(Map<String, dynamic> json) {
		final displayName = json['display_name'] as String? ?? '';
		final parts = displayName.split(',');
		final shortName = parts.isNotEmpty ? parts.first.trim() : 'Ubicación';
		return SearchResult(
			name: shortName,
			address: displayName,
			latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
			longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
		);
	}
}

class LocationSearchService {
	static const String _googleApiKey = String.fromEnvironment(
		'MAPS_API_KEY',
		defaultValue: '',
	);

	/// Search locations by text query using a multi-tiered resilient approach
	Future<List<SearchResult>> search(String query) async {
		if (query.trim().isEmpty) return [];

		// Tier 1: Try Native Platform Geocoding
		try {
			final locations = await native_geo.locationFromAddress(query);
			if (locations.isNotEmpty) {
				final List<SearchResult> results = [];
				for (var loc in locations.take(5)) {
					String addrText = query;
					try {
						final placemarks = await native_geo.placemarkFromCoordinates(
							loc.latitude,
							loc.longitude,
						);
						if (placemarks.isNotEmpty) {
							final p = placemarks.first;
							addrText = [
								if (p.street?.isNotEmpty ?? false) p.street,
								if (p.subLocality?.isNotEmpty ?? false) p.subLocality,
								if (p.locality?.isNotEmpty ?? false) p.locality,
								if (p.country?.isNotEmpty ?? false) p.country,
							].join(', ');
						}
					} catch (_) {}

					results.add(SearchResult(
						name: query,
						address: addrText.isNotEmpty ? addrText : query,
						latitude: loc.latitude,
						longitude: loc.longitude,
					));
				}
				if (results.isNotEmpty) return results;
			}
		} catch (e) {
			debugPrint('Native geocoding tier error: $e');
		}

		// Tier 2: Try Google Maps Geocoding REST API (if key is configured)
		if (_googleApiKey.isNotEmpty) {
			try {
				final url = Uri.parse(
					'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_googleApiKey',
				);
				final response = await http.get(url).timeout(const Duration(seconds: 5));
				if (response.statusCode == 200) {
					final data = json.decode(response.body);
					final results = data['results'] as List?;
					if (results != null && results.isNotEmpty) {
						return results
								.map((item) => SearchResult.fromGoogle(item))
								.take(5)
								.toList();
					}
				}
			} catch (e) {
				debugPrint('Google Geocoding REST API error: $e');
			}
		}

		// Tier 3: Resilient Fallback to OpenStreetMap Nominatim
		try {
			final url = Uri.parse(
				'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
			);
			final response = await http.get(url, headers: {
				'User-Agent': 'GeoAlarmApp/1.0',
			}).timeout(const Duration(seconds: 5));

			if (response.statusCode == 200) {
				final List data = json.decode(response.body);
				return data.map((item) => SearchResult.fromNominatim(item)).toList();
			}
		} catch (e) {
			debugPrint('Nominatim fallback geocoding error: $e');
		}

		return [];
	}
}
