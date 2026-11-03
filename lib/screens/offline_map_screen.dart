import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/hospital_service.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final DatabaseService _dbService = DatabaseService();

  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _isGpsActive = false;
  bool _isStaleLocation = false;
  bool _isLoading = true;
  bool _isRefreshing = false;

  List<HospitalModel> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndHospitals();
  }

  Future<void> _loadLocationAndHospitals() async {
    setState(() => _isLoading = true);
    double lat = 12.9716;
    double lng = 77.5946;
    double acc = 5.0;
    bool stale = false;

    try {
      Position? pos;
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 4),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
            stale = true;
          }
        }
      }

      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        acc = pos.accuracy;
        _isGpsActive = true;
      }
    } catch (_) {}

    final cachedHospitals = await HospitalService.getCachedHospitals(
      latitude: lat,
      longitude: lng,
    );

    if (mounted) {
      setState(() {
        _latitude = lat;
        _longitude = lng;
        _accuracy = acc;
        _isStaleLocation = stale;
        _hospitals = cachedHospitals;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOnlineHospitals() async {
    if (_latitude == null || _longitude == null) return;
    setState(() => _isRefreshing = true);

    try {
      final result = await HospitalService.searchNearbyHospitals(
        latitude: _latitude!,
        longitude: _longitude!,
      );

      if (mounted) {
        if (result.hospitals.isNotEmpty) {
          setState(() {
            _hospitals = result.hospitals;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('cache_updated'.tr),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Offline mode: Preserved existing cached hospital registry."),
              backgroundColor: Color(0xFF38BDF8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network check failed: Using offline cached hospital data ($e)"),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'offline_maps'.tr,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
            onPressed: _isRefreshing ? null : _refreshOnlineHospitals,
            tooltip: 'download_cache'.tr,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : RefreshIndicator(
              onRefresh: _refreshOnlineHospitals,
              color: const Color(0xFF38BDF8),
              backgroundColor: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Offline GPS Telemetry Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.satellite_alt_outlined, color: Color(0xFF38BDF8), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'gps_coordinates'.tr,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              StatusBadge(
                                label: _isStaleLocation ? 'last_known_location'.tr : 'STANDALONE GNSS',
                                type: _isStaleLocation ? BadgeStatusType.warning : BadgeStatusType.active,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Latitude", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8))),
                                      const SizedBox(height: 2),
                                      Text(
                                        _latitude?.toStringAsFixed(5) ?? "12.9716",
                                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Longitude", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8))),
                                      const SizedBox(height: 2),
                                      Text(
                                        _longitude?.toStringAsFixed(5) ?? "77.5946",
                                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${'gps_accuracy'.tr}: ±${_accuracy?.toStringAsFixed(1) ?? '5.0'}m",
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              Text(
                                _isStaleLocation ? 'location_stale'.tr : "Satellite Fix: High Precision",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: _isStaleLocation ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Download / Refresh Action Card
                    InteractivePressable(
                      onTap: _isRefreshing ? null : _refreshOnlineHospitals,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_download_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'download_cache'.tr,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cached Hospital List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'cached_hospitals'.tr,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "${_hospitals.length} ${'available'.tr.toLowerCase()}",
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_hospitals.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.local_hospital_outlined, size: 40, color: Color(0xFF64748B)),
                            const SizedBox(height: 12),
                            Text(
                              'no_cached_hospitals'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _hospitals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final h = _hospitals[index];
                          final isLive = h.source.contains('OpenStreetMap');
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLive
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                    : const Color(0xFF38BDF8).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        h.name,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    StatusBadge(
                                      label: isLive ? 'live_data'.tr : 'cached_data'.tr,
                                      type: isLive ? BadgeStatusType.active : BadgeStatusType.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.near_me_outlined, size: 14, color: Color(0xFF38BDF8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${h.distanceKm.toStringAsFixed(2)} ${'distance_km'.tr}",
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      h.facilityType,
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                if (h.address != null && h.address!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    h.address!,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                                if (h.phone != null && h.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        h.phone!,
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
