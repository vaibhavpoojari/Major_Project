import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:http/http.dart' as http;

enum HospitalLookupStatus {
  success,
  noResults,
  timeout,
  apiError,
  networkError,
}

class HospitalSearchResult {
  final List<HospitalModel> hospitals;
  final HospitalLookupStatus status;
  final String statusMessage;
  final int discoveredCount;
  final double radiusMeters;
  final String? activeEndpoint;

  const HospitalSearchResult({
    required this.hospitals,
    required this.status,
    required this.statusMessage,
    this.discoveredCount = 0,
    this.radiusMeters = 10000,
    this.activeEndpoint,
  });
}

class HospitalModel {
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String facilityType;
  final String emergencyCapability;
  final String ownership;
  final int priorityTier;
  final String source;

  HospitalModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.facilityType = 'Hospital',
    this.emergencyCapability = 'Unavailable',
    this.ownership = 'Unavailable',
    this.priorityTier = 1,
    this.source = 'OpenStreetMap',
  });

  Map<String, dynamic> toMap() {
    return {
      'facilityName': name,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
      'address': address ?? 'Address not available in OSM',
      'dispatchPhone': phone ?? '',
      'phone': phone ?? '',
      'hasValidPhone': phone != null && phone!.trim().isNotEmpty,
      'email': email ?? '',
      'website': website ?? '',
      'facilityType': facilityType,
      'emergencyCapability': emergencyCapability,
      'ownership': ownership,
      'priorityTier': priorityTier,
      'source': source,
    };
  }
}

class HospitalService {
  static const List<String> _overpassEndpoints = [
    'https://overpass.openstreetmap.fr/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static const String _osmUserAgent =
      'AccidentGuard/1.0 (Emergency Alert System; contact@accidentguard.org)';

  /// Normalize and validate a phone number extracted from OpenStreetMap tags.
  /// Handles quotation marks, multiple comma/slash/semicolon numbers, STD prefixes,
  /// and standard Indian/international mobile and landline formats.
  static String? normalizePhoneNumber(String? raw) {
    if (raw == null) return null;
    String str = raw.trim();
    if (str.isEmpty) return null;

    // 1. Remove surrounding or stray quotes
    str = str.replaceAll(RegExp(r'["'']'), '').trim();

    // 2. If multiple numbers are separated by ; , / or "or", pick the first valid candidate
    final separators = RegExp(r'[;/,\n]|(\s+or\s+)');
    if (str.contains(separators)) {
      final parts = str.split(separators);
      for (final part in parts) {
        final candidate = normalizePhoneNumber(part);
        if (candidate != null) return candidate;
      }
      return null;
    }

    // 3. Remove spaces, dashes, dots, parentheses
    final bool hasPlus = str.startsWith('+');
    final String digitsOnly = str.replaceAll(RegExp(r'\D'), '');

    // Must have reasonable digit length (standard international numbers are 8-15 digits)
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      return null;
    }

    // 4. Format with proper country code
    if (hasPlus) {
      return '+$digitsOnly';
    }

    // If 11 digits starting with 0 (e.g. Indian STD landline 08022221111 or mobile 09876543210)
    if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      return '+91${digitsOnly.substring(1)}';
    }

    // If 12 digits starting with 91 (e.g. 918022868423 or 919876543210)
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return '+$digitsOnly';
    }

    // If 10 digits (standard Indian mobile/landline without 0 or +91 prefix)
    if (digitsOnly.length == 10) {
      return '+91$digitsOnly';
    }

    // Default international format
    return '+$digitsOnly';
  }

  /// Search available hospital contact fields in OpenStreetMap tags in order of preference
  /// and return the first normalized valid phone number.
  static String? extractHospitalPhone(Map<String, dynamic> tags) {
    const candidateKeys = [
      'phone',
      'contact:phone',
      'telephone',
      'contact:telephone',
      'emergency:phone',
      'phone:mobile',
      'contact:mobile',
      'mobile',
    ];

    for (final key in candidateKeys) {
      final val = tags[key]?.toString().trim();
      if (val != null && val.isNotEmpty) {
        final normalized = normalizePhoneNumber(val);
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return null;
  }

  /// Calculate geodesic distance between two coordinates in kilometers using Haversine formula
  static double calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Classify a healthcare facility based on OpenStreetMap tags
  static HospitalModel classifyFacility({
    required String name,
    required double latitude,
    required double longitude,
    required double distanceKm,
    String? address,
    String? phone,
    String? email,
    String? website,
    Map<String, dynamic> tags = const {},
  }) {
    final nameLower = name.toLowerCase().trim();
    final amenity = tags['amenity']?.toString().toLowerCase().trim() ?? '';
    final healthcare = tags['healthcare']?.toString().toLowerCase().trim() ?? '';
    final building = tags['building']?.toString().toLowerCase().trim() ?? '';
    final emergency = tags['emergency']?.toString().toLowerCase().trim() ?? '';
    final operatorType = tags['operator:type']?.toString().toLowerCase().trim() ?? '';
    final operatorName = tags['operator']?.toString().toLowerCase().trim() ?? '';
    final ownershipTag = tags['ownership']?.toString().toLowerCase().trim() ?? '';

    // 1. Emergency Capability
    String emergencyCapability = 'Unavailable';
    if (emergency == 'yes' ||
        tags['emergency:service']?.toString().toLowerCase() == 'yes' ||
        tags['healthcare:speciality']?.toString().toLowerCase().contains('emergency') == true) {
      emergencyCapability = 'Yes';
    } else if (emergency == 'no') {
      emergencyCapability = 'No';
    }

    // 2. Determine if it is a Proper Hospital vs Clinic/Small Facility
    bool isProperHospital = (amenity == 'hospital' ||
        healthcare == 'hospital' ||
        building == 'hospital' ||
        tags['healthcare:speciality'] != null ||
        nameLower.contains('hospital') ||
        nameLower.contains('nursing home') ||
        nameLower.contains('medical college') ||
        nameLower.contains('trauma care') ||
        nameLower.contains('health city'));

    bool isClinic = !isProperHospital &&
        (amenity == 'clinic' ||
            healthcare == 'clinic' ||
            amenity == 'doctors' ||
            healthcare == 'doctor' ||
            healthcare == 'centre' ||
            nameLower.contains('clinic') ||
            nameLower.contains('dispensary') ||
            nameLower.contains('polyclinic') ||
            nameLower.contains('health centre') ||
            nameLower.contains('health center') ||
            nameLower.contains('consulting room'));

    // Fallback classification if neither explicitly set
    if (!isProperHospital && !isClinic) {
      if (nameLower.contains('hospital')) {
        isProperHospital = true;
      } else {
        isClinic = true;
      }
    }

    // Determine facilityType string for display
    String facilityType;
    if (isProperHospital) {
      facilityType = (emergencyCapability == 'Yes') ? 'Emergency Hospital' : 'Hospital';
    } else {
      if (amenity == 'doctors' || healthcare == 'doctor') {
        facilityType = 'Doctor / Clinic';
      } else if (amenity == 'clinic' || healthcare == 'clinic') {
        facilityType = 'Clinic';
      } else {
        facilityType = 'Healthcare Centre';
      }
    }

    // 3. Ownership Determination (Private vs Government/Public vs Unavailable)
    String ownership = 'Unavailable';
    bool isGovt = (operatorType == 'government' ||
        operatorType == 'public' ||
        operatorType == 'state' ||
        ownershipTag == 'government' ||
        ownershipTag == 'public' ||
        tags['government'] != null ||
        operatorName.contains('government') ||
        operatorName.contains('ministry') ||
        operatorName.contains('dept of health') ||
        operatorName.contains('health department') ||
        operatorName.contains('state govt') ||
        operatorName.contains('central govt') ||
        nameLower.startsWith('government ') ||
        nameLower.startsWith('govt ') ||
        nameLower.contains('district hospital') ||
        nameLower.contains('taluk hospital') ||
        nameLower.contains('taluka hospital') ||
        nameLower.contains('civil hospital') ||
        nameLower.contains('esi hospital') ||
        nameLower.contains('primary health centre') ||
        nameLower.contains('community health centre') ||
        nameLower.contains('chc') ||
        nameLower.contains('phc'));

    bool isPrivate = (operatorType == 'private' ||
        operatorType == 'commercial' ||
        ownershipTag == 'private' ||
        nameLower.contains('private') ||
        nameLower.contains('apollo') ||
        nameLower.contains('fortis') ||
        nameLower.contains('manipal') ||
        nameLower.contains('aster') ||
        nameLower.contains('max super') ||
        nameLower.contains('narayana') ||
        nameLower.contains('columbia asia') ||
        nameLower.contains('sparsh') ||
        nameLower.contains('sakra') ||
        nameLower.contains('trust hospital') ||
        nameLower.contains('memorial hospital') ||
        nameLower.contains('mission hospital'));

    if (isGovt) {
      ownership = 'Government/Public';
    } else if (isPrivate) {
      ownership = 'Private';
    }

    // 4. Priority Tier
    // Tier 1: Emergency-Capable Hospitals
    // Tier 2: All Other Real Hospitals (Private, Government, or Ownership Unavailable)
    // Tier 3: Clinics and Small Medical Centres (Fallback only)
    int priorityTier;
    if (!isProperHospital) {
      priorityTier = 3;
    } else if (emergencyCapability == 'Yes') {
      priorityTier = 1;
    } else {
      priorityTier = 2;
    }

    return HospitalModel(
      name: name,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      address: address,
      phone: phone,
      email: email,
      website: website,
      facilityType: facilityType,
      emergencyCapability: emergencyCapability,
      ownership: ownership,
      priorityTier: priorityTier,
      source: 'OpenStreetMap',
    );
  }

  /// Prioritize and select up to 3 best nearby hospitals from a raw list
  /// 1. Prefer actual hospitals over clinics.
  /// 2. Among hospitals, emergency-capable hospitals get preference.
  /// 3. Private, Government, and General hospitals are all valid proper hospitals.
  /// 4. Never drop a closer private/general hospital for a farther government hospital.
  /// 5. Clinics are used ONLY if fewer than 3 proper hospitals are found.
  /// 6. Returns at most 3 facilities sorted by distance.
  static List<HospitalModel> prioritizeHospitals(List<HospitalModel> facilities) {
    if (facilities.isEmpty) return [];

    final emergencyHospitals = facilities.where((f) => f.priorityTier == 1).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final normalHospitals = facilities.where((f) => f.priorityTier == 2).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final clinics = facilities.where((f) => f.priorityTier == 3).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final List<HospitalModel> selected = [];

    // Step 1: Add Emergency Hospitals first
    for (final h in emergencyHospitals) {
      if (selected.length < 3) {
        selected.add(h);
      }
    }

    // Step 2: Add other Proper Hospitals (Private, Govt, General sorted by distance)
    for (final h in normalHospitals) {
      if (selected.length < 3) {
        selected.add(h);
      }
    }

    // Step 3: Fallback to clinics if fewer than 3 proper hospitals are found
    if (selected.length < 3) {
      for (final c in clinics) {
        if (selected.length < 3) {
          selected.add(c);
        }
      }
    }

    // Sort final selected results by distance for accurate navigation
    selected.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return selected;
  }

  /// Safe double parser for coordinates that handles both numbers and strings
  static double? _parseCoord(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim());
    return null;
  }

  /// Core search method: queries OpenStreetMap Overpass with auto-retry at 25km,
  /// fallback to Nominatim, proper timeouts, and structured status reporting.
  static Future<HospitalSearchResult> searchNearbyHospitals({
    required double latitude,
    required double longitude,
  }) async {
    developer.log('Searching nearby hospitals...', name: 'HospitalService');
    developer.log('GPS coordinates: Lat $latitude, Lng $longitude', name: 'HospitalService');

    // 1. First attempt with 10 km radius
    final queryResult = await _queryOverpassWithStatus(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: 10000,
    );

    List<HospitalModel> allFacilities = queryResult.hospitals;
    double usedRadius = 10000;
    String? activeEndpoint = queryResult.endpointUsed;

    // 2. If Overpass server was reachable but returned 0 within 10 km, retry with 25 km
    if (allFacilities.isEmpty && queryResult.isServerReachable) {
      developer.log('No healthcare facilities found within 10 km. Retrying with 25 km radius...', name: 'HospitalService');
      final retryResult = await _queryOverpassWithStatus(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 25000,
      );
      allFacilities = retryResult.hospitals;
      usedRadius = 25000;
      if (retryResult.endpointUsed != null) {
        activeEndpoint = retryResult.endpointUsed;
      }
    }

    // 3. Fallback to Nominatim if Overpass was completely unreachable or failed
    if (allFacilities.isEmpty && !queryResult.isServerReachable) {
      developer.log('Overpass endpoints unreachable. Attempting OpenStreetMap Nominatim fallback...', name: 'HospitalService');
      final nominatimResult = await _queryNominatimFallback(
        latitude: latitude,
        longitude: longitude,
      );
      if (nominatimResult.isNotEmpty) {
        allFacilities = nominatimResult;
        activeEndpoint = 'Nominatim (OSM Fallback)';
        developer.log('Nominatim fallback succeeded: discovered ${allFacilities.length} facilities.', name: 'HospitalService');
      }
    }

    final int hospitalCount = allFacilities.where((f) => f.priorityTier <= 2).length;
    final int clinicCount = allFacilities.where((f) => f.priorityTier == 3).length;

    developer.log(
      'Discovered facilities: radius=${usedRadius.toInt()}m (${(usedRadius / 1000).toStringAsFixed(1)}km), hospitals=$hospitalCount, clinics=$clinicCount, total=${allFacilities.length}',
      name: 'HospitalService',
    );

    if (allFacilities.isEmpty) {
      HospitalLookupStatus status;
      String message;
      if (!queryResult.isServerReachable) {
        if (queryResult.lastErrorMessage.toLowerCase().contains('timeout')) {
          status = HospitalLookupStatus.timeout;
          message = 'Hospital lookup timed out (Overpass servers busy)';
        } else {
          status = HospitalLookupStatus.apiError;
          message = 'Hospital lookup failed (OpenStreetMap API error)';
        }
      } else {
        status = HospitalLookupStatus.noResults;
        message = 'No healthcare facilities found within ${(usedRadius / 1000).toStringAsFixed(0)} km';
      }
      developer.log(message, name: 'HospitalService');
      return HospitalSearchResult(
        hospitals: [],
        status: status,
        statusMessage: message,
        discoveredCount: 0,
        radiusMeters: usedRadius,
        activeEndpoint: activeEndpoint,
      );
    }

    final top3 = prioritizeHospitals(allFacilities);

    developer.log('Final prioritized top ${top3.length} hospitals:', name: 'HospitalService');
    for (int i = 0; i < top3.length; i++) {
      final h = top3[i];
      final phoneInfo = h.phone != null && h.phone!.isNotEmpty
          ? '${h.phone!.substring(0, min(6, h.phone!.length))}****'
          : 'Missing in OSM';
      developer.log(
        '  #${i + 1}: ${h.name} (${h.distanceKm.toStringAsFixed(2)} km) | Type: ${h.facilityType} | Emergency: ${h.emergencyCapability} | Phone: $phoneInfo',
        name: 'HospitalService',
      );
    }

    final nearest = top3.first;
    if (nearest.phone == null || nearest.phone!.isEmpty) {
      developer.log(
        'Diagnostic: Selected nearest hospital (${nearest.name}) has no phone listed in OpenStreetMap directory.',
        name: 'HospitalService',
      );
    }

    return HospitalSearchResult(
      hospitals: top3,
      status: HospitalLookupStatus.success,
      statusMessage: 'Discovered ${top3.length} nearby healthcare facilities',
      discoveredCount: allFacilities.length,
      radiusMeters: usedRadius,
      activeEndpoint: activeEndpoint,
    );
  }

  /// Query OpenStreetMap for up to 3 top prioritized nearby hospitals (Backward-compatible)
  static Future<List<HospitalModel>> findTopNearbyHospitals({
    required double latitude,
    required double longitude,
  }) async {
    final result = await searchNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
    );
    return result.hospitals;
  }

  /// Query OpenStreetMap for nearest hospital with auto-retry at larger radius
  static Future<HospitalModel?> findNearestRealHospital({
    required double latitude,
    required double longitude,
  }) async {
    final topHospitals = await findTopNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
    );
    return topHospitals.isNotEmpty ? topHospitals.first : null;
  }

  static Future<_QueryResult> _queryOverpassWithStatus({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final radiusInt = radiusMeters.toInt();
    final query = '''
[out:json][timeout:10];
(
  node["amenity"="hospital"](around:$radiusInt,$latitude,$longitude);
  way["amenity"="hospital"](around:$radiusInt,$latitude,$longitude);
  relation["amenity"="hospital"](around:$radiusInt,$latitude,$longitude);
  node["healthcare"="hospital"](around:$radiusInt,$latitude,$longitude);
  way["healthcare"="hospital"](around:$radiusInt,$latitude,$longitude);
  relation["healthcare"="hospital"](around:$radiusInt,$latitude,$longitude);
  node["amenity"="clinic"](around:$radiusInt,$latitude,$longitude);
  way["amenity"="clinic"](around:$radiusInt,$latitude,$longitude);
  node["healthcare"="clinic"](around:$radiusInt,$latitude,$longitude);
  way["healthcare"="clinic"](around:$radiusInt,$latitude,$longitude);
);
out center tags;
''';

    String lastError = '';

    for (final endpoint in _overpassEndpoints) {
      try {
        final uri = Uri.parse(endpoint);
        developer.log('Querying Overpass API endpoint: $endpoint (radius: ${radiusInt}m)...', name: 'HospitalService');
        final response = await http
            .post(
              uri,
              headers: {
                'Accept': 'application/json',
                'User-Agent': _osmUserAgent,
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 10));

        developer.log('Endpoint $endpoint returned status: ${response.statusCode}', name: 'HospitalService');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['elements'] is List) {
            final List<HospitalModel> results = [];
            final Set<String> seenNames = {};

            for (final element in data['elements']) {
              if (element is! Map) continue;

              final tags = element['tags'] is Map
                  ? Map<String, dynamic>.from(element['tags'])
                  : <String, dynamic>{};

              double? hospLat = _parseCoord(element['lat']);
              double? hospLng = _parseCoord(element['lon']);

              if (hospLat == null || hospLng == null) {
                if (element['center'] is Map) {
                  final center = Map<String, dynamic>.from(element['center']);
                  hospLat = _parseCoord(center['lat']);
                  hospLng = _parseCoord(center['lon']);
                }
              }

              if (hospLat == null || hospLng == null) continue;

              // Name extraction
              String name = tags['name']?.toString().trim() ??
                  tags['name:en']?.toString().trim() ??
                  tags['official_name']?.toString().trim() ??
                  tags['alt_name']?.toString().trim() ??
                  '';

              if (name.isEmpty) {
                name = tags['operator']?.toString().trim() ?? '';
              }
              if (name.isEmpty) {
                continue; // Skip completely unnamed geometry nodes
              }

              // De-duplicate by name
              final nameKey = name.toLowerCase();
              if (seenNames.contains(nameKey)) continue;
              seenNames.add(nameKey);

              // Phone extraction & normalization across all OSM phone keys
              final String? phone = extractHospitalPhone(tags);

              // Address extraction
              final String? address = _extractAddress(tags);

              // Website extraction
              final String? website = tags['website']?.toString().trim() ??
                  tags['contact:website']?.toString().trim();

              // Email extraction
              final String? email = tags['email']?.toString().trim() ??
                  tags['contact:email']?.toString().trim();

              final double distanceKm = calculateHaversineDistanceKm(
                latitude,
                longitude,
                hospLat,
                hospLng,
              );

              final model = classifyFacility(
                name: name,
                latitude: hospLat,
                longitude: hospLng,
                distanceKm: distanceKm,
                address: address,
                phone: phone,
                email: email,
                website: website,
                tags: tags,
              );

              results.add(model);
            }

            return _QueryResult(
              hospitals: results,
              isServerReachable: true,
              endpointUsed: endpoint,
            );
          }
        } else {
          lastError = 'HTTP ${response.statusCode}';
          developer.log(
            'Endpoint $endpoint returned error status ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
            name: 'HospitalService',
          );
        }
      } catch (e) {
        lastError = e.toString();
        developer.log('Overpass request failed on $endpoint: $e', name: 'HospitalService');
      }
    }

    return _QueryResult(
      hospitals: [],
      isServerReachable: false,
      lastErrorMessage: lastError,
    );
  }

  /// Nominatim OSM secondary fallback when Overpass API mirrors are busy or unreachable
  static Future<List<HospitalModel>> _queryNominatimFallback({
    required double latitude,
    required double longitude,
  }) async {
    try {
      const delta = 0.09; // ~10 km bounding box
      final left = longitude - delta;
      final right = longitude + delta;
      final top = latitude + delta;
      final bottom = latitude - delta;

      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=hospital&viewbox=$left,$top,$right,$bottom&bounded=1&addressdetails=1&extratags=1&limit=10';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': _osmUserAgent,
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<HospitalModel> results = [];
        final Set<String> seenNames = {};

        for (final item in data) {
          if (item is! Map) continue;
          final double? hospLat = _parseCoord(item['lat']);
          final double? hospLng = _parseCoord(item['lon']);
          if (hospLat == null || hospLng == null) continue;

          final String displayName = item['display_name']?.toString() ?? 'Hospital';
          final String name = displayName.split(',').first.trim();
          if (name.isEmpty || seenNames.contains(name.toLowerCase())) continue;
          seenNames.add(name.toLowerCase());

          final extra = item['extratags'] is Map
              ? Map<String, dynamic>.from(item['extratags'])
              : <String, dynamic>{};

          final String? phone = extractHospitalPhone(extra);
          final double distanceKm = calculateHaversineDistanceKm(
            latitude,
            longitude,
            hospLat,
            hospLng,
          );

          results.add(
            classifyFacility(
              name: name,
              latitude: hospLat,
              longitude: hospLng,
              distanceKm: distanceKm,
              address: displayName,
              phone: phone,
              tags: extra,
            ),
          );
        }

        return results;
      }
    } catch (e) {
      developer.log('Nominatim fallback query failed: $e', name: 'HospitalService');
    }
    return [];
  }

  static String? _extractAddress(Map<String, dynamic> tags) {
    if (tags['addr:full'] != null && tags['addr:full'].toString().trim().isNotEmpty) {
      return tags['addr:full'].toString().trim();
    }

    final List<String> parts = [];
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber'].toString().trim());
    if (tags['addr:street'] != null) parts.add(tags['addr:street'].toString().trim());
    if (tags['addr:suburb'] != null) parts.add(tags['addr:suburb'].toString().trim());
    if (tags['addr:city'] != null) parts.add(tags['addr:city'].toString().trim());
    if (tags['addr:postcode'] != null) parts.add(tags['addr:postcode'].toString().trim());

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return null;
  }

  /// Backward-compatibility helper for any legacy list callers
  static Future<List<Map<String, dynamic>>> findNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusMeters = 10000,
  }) async {
    final result = await searchNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
    );
    return result.hospitals.map((h) => h.toMap()).toList();
  }
}

class _QueryResult {
  final List<HospitalModel> hospitals;
  final bool isServerReachable;
  final String? endpointUsed;
  final String lastErrorMessage;

  _QueryResult({
    required this.hospitals,
    required this.isServerReachable,
    this.endpointUsed,
    this.lastErrorMessage = '',
  });
}