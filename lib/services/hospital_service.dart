import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

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
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

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
      priorityTier = 3; // Clinic fallback
    } else if (emergencyCapability == 'Yes') {
      priorityTier = 1; // Emergency Hospital
    } else {
      priorityTier = 2; // Normal Real Hospital (Private / Govt / General)
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
  /// Selection Rules:
  /// 1. Prefer actual hospitals over clinics.
  /// 2. Among hospitals, emergency-capable hospitals get preference.
  /// 3. Private, Government, and General hospitals are all valid proper hospitals.
  /// 4. Never drop a closer private/general hospital for a farther government hospital.
  /// 5. Clinics are used ONLY if fewer than 3 proper hospitals are found.
  /// 6. Returns at most 3 facilities sorted by distance.
  static List<HospitalModel> prioritizeHospitals(List<HospitalModel> facilities) {
    if (facilities.isEmpty) return [];

    // Separate into proper hospitals vs clinics
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

    // Step 3: If still fewer than 3, fallback to Clinics
    if (selected.length < 3) {
      for (final c in clinics) {
        if (selected.length < 3) {
          selected.add(c);
        }
      }
    }

    // Sort the final selected results primarily by distance for accurate navigation
    selected.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return selected;
  }

  /// Query OpenStreetMap for up to 3 top prioritized nearby hospitals
  static Future<List<HospitalModel>> findTopNearbyHospitals({
    required double latitude,
    required double longitude,
  }) async {
    print('Searching nearby hospitals...');
    print('GPS coordinates: Lat $latitude, Lng $longitude');

    // 1. First attempt with 10 km radius
    final queryResult = await _queryOverpassWithStatus(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: 10000,
    );

    List<HospitalModel> allFacilities = queryResult.hospitals;

    // 2. If Overpass server was reachable but returned 0 within 10 km, retry with 25 km
    if (allFacilities.isEmpty && queryResult.isServerReachable) {
      print('HospitalService: No healthcare facilities found within 10 km. Retrying with 25 km radius...');
      final retryResult = await _queryOverpassWithStatus(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 25000,
      );
      allFacilities = retryResult.hospitals;
    }

    final int hospitalCount = allFacilities.where((f) => f.priorityTier <= 2).length;
    final int clinicCount = allFacilities.where((f) => f.priorityTier == 3).length;

    print('Discovered facilities from OpenStreetMap:');
    print('  Hospitals discovered: $hospitalCount');
    print('  Clinics discovered: $clinicCount');

    if (allFacilities.isEmpty) {
      print('HospitalService: No healthcare facilities found in vicinity.');
      return [];
    }

    print('Discovered Facility Details:');
    for (final f in allFacilities) {
      print('  • ${f.name} (${f.distanceKm.toStringAsFixed(2)} km) | Type: ${f.facilityType} | Emergency: ${f.emergencyCapability} | Ownership: ${f.ownership}');
    }

    final top3 = prioritizeHospitals(allFacilities);

    print('Final selected top ${top3.length}:');
    for (int i = 0; i < top3.length; i++) {
      final h = top3[i];
      print(
        '  #${i + 1}: ${h.name} (${h.distanceKm.toStringAsFixed(2)} km) | Type: ${h.facilityType} | Emergency: ${h.emergencyCapability} | Ownership: ${h.ownership} | Phone: ${h.phone ?? "Unavailable"}',
      );
    }

    return top3;
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
    final query = '''
[out:json][timeout:8];
(
  node["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  node["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  way["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  relation["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="clinic"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="clinic"](around:$radiusMeters,$latitude,$longitude);
  node["healthcare"="clinic"](around:$radiusMeters,$latitude,$longitude);
  way["healthcare"="clinic"](around:$radiusMeters,$latitude,$longitude);
);
out center tags;
''';

    for (final endpoint in _overpassEndpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                'User-Agent': 'AccidentGuardEmergencySystem/1.0',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 6));

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

              double? hospLat;
              double? hospLng;

              if (element['lat'] is num && element['lon'] is num) {
                hospLat = (element['lat'] as num).toDouble();
                hospLng = (element['lon'] as num).toDouble();
              } else if (element['center'] is Map) {
                final center = Map<String, dynamic>.from(element['center']);
                if (center['lat'] is num && center['lon'] is num) {
                  hospLat = (center['lat'] as num).toDouble();
                  hospLng = (center['lon'] as num).toDouble();
                }
              }

              if (hospLat == null || hospLng == null) continue;

              // Name extraction
              String name = tags['name']?.toString().trim() ??
                  tags['name:en']?.toString().trim() ??
                  tags['official_name']?.toString().trim() ??
                  '';

              if (name.isEmpty) {
                name = tags['operator']?.toString().trim() ?? '';
              }
              if (name.isEmpty) {
                continue; // Skip completely unnamed nodes
              }

              // De-duplicate by name
              if (seenNames.contains(name.toLowerCase())) continue;
              seenNames.add(name.toLowerCase());

              // Phone extraction
              String? phone = tags['phone']?.toString().trim() ??
                  tags['contact:phone']?.toString().trim() ??
                  tags['emergency:phone']?.toString().trim() ??
                  tags['telephone']?.toString().trim();

              if (phone != null && phone.isEmpty) {
                phone = null;
              }

              // Address extraction
              String? address = _extractAddress(tags);

              // Website extraction
              String? website = tags['website']?.toString().trim() ??
                  tags['contact:website']?.toString().trim();

              // Email extraction
              String? email = tags['email']?.toString().trim() ??
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

            return _QueryResult(hospitals: results, isServerReachable: true);
          }
        } else {
          print('HospitalService: Endpoint $endpoint returned status ${response.statusCode}');
        }
      } catch (e) {
        print('Hospital API failed on endpoint $endpoint: $e');
      }
    }

    return _QueryResult(hospitals: [], isServerReachable: false);
  }

  static String? _extractAddress(Map<String, dynamic> tags) {
    if (tags['addr:full'] != null && tags['addr:full'].toString().trim().isNotEmpty) {
      return tags['addr:full'].toString().trim();
    }

    List<String> parts = [];
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
    final result = await _queryOverpassWithStatus(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    return result.hospitals.map((h) => h.toMap()).toList();
  }
}

class _QueryResult {
  final List<HospitalModel> hospitals;
  final bool isServerReachable;

  _QueryResult({
    required this.hospitals,
    required this.isServerReachable,
  });
}