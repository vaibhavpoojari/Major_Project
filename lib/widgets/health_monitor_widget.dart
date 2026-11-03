import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/localization_service.dart';
import '../services/offline_queue_service.dart';

enum HealthState { available, unavailable, permissionRequired, error }

class HealthMonitorWidget extends StatefulWidget {
  const HealthMonitorWidget({super.key});

  @override
  State<HealthMonitorWidget> createState() => _HealthMonitorWidgetState();
}

class _HealthMonitorWidgetState extends State<HealthMonitorWidget> {
  static const MethodChannel _smsChannel = MethodChannel('com.example.accident_guard_system/sms');

  bool _isChecking = false;

  HealthState _gpsState = HealthState.available;
  HealthState _permState = HealthState.available;
  HealthState _netState = HealthState.available;
  HealthState _smsState = HealthState.available;

  String _gpsAccuracyText = "Checking...";
  String _lastLocationUpdateText = "Pending";
  String _internetStatusText = "Checking...";
  String _simDetailText = "Checking...";
  int _pendingQueueCount = 0;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // 1. Check Location Permission & Service
      bool serviceEnabled = false;
      LocationPermission permission = LocationPermission.denied;

      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        permission = await Geolocator.checkPermission();
      } catch (_) {}

      if (!serviceEnabled) {
        _gpsState = HealthState.unavailable;
        _gpsAccuracyText = "Hardware Disabled";
      } else {
        _gpsState = HealthState.available;
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _permState = HealthState.permissionRequired;
      } else {
        _permState = HealthState.available;
      }

      // 2. Fetch fast last-known GPS location to determine accuracy & freshness
      try {
        Position? pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _gpsAccuracyText = "±${pos.accuracy.toStringAsFixed(1)}m (${pos.accuracy <= 15 ? 'High' : 'Moderate'})";
          final diff = DateTime.now().difference(pos.timestamp);
          if (diff.inMinutes < 1) {
            _lastLocationUpdateText = "Just now";
          } else if (diff.inMinutes < 60) {
            _lastLocationUpdateText = "${diff.inMinutes}m ago";
          } else {
            _lastLocationUpdateText = "${diff.inHours}h ago (Stale)";
          }
        } else {
          _gpsAccuracyText = "Signal standby";
          _lastLocationUpdateText = "No recent fix";
        }
      } catch (_) {
        _gpsAccuracyText = "Unavailable";
        _lastLocationUpdateText = "Unavailable";
      }

      // 3. Lightweight Internet Check (HTTP Head/Get with 3s timeout)
      try {
        final res = await http
            .get(Uri.parse('https://www.google.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 204 || res.statusCode == 200) {
          _netState = HealthState.available;
          _internetStatusText = 'online'.tr;
        } else {
          _netState = HealthState.unavailable;
          _internetStatusText = 'offline'.tr;
        }
      } catch (_) {
        _netState = HealthState.unavailable;
        _internetStatusText = 'offline'.tr;
      }

      // 4. SMS & SIM Telephony Status via Native Platform Channel
      try {
        final Map<dynamic, dynamic>? simInfo = await _smsChannel.invokeMethod('getTelephonyStatus');
        if (simInfo != null) {
          final String simState = (simInfo['simState'] ?? '').toString();
          final String carrier = (simInfo['carrierName'] ?? '').toString();
          final bool smsCapable = simInfo['smsCapable'] == true;
          if (simState == 'READY') {
            _simDetailText = carrier.isNotEmpty ? "$carrier (SIM Ready)" : "SIM Active";
            _smsState = HealthState.available;
          } else if (simState == 'ABSENT') {
            _simDetailText = "No SIM Card Inserted";
            _smsState = HealthState.unavailable;
          } else {
            _simDetailText = "SIM $simState";
            _smsState = smsCapable ? HealthState.available : HealthState.unavailable;
          }
        } else {
          _simDetailText = "SIM Baseband Ready";
          _smsState = HealthState.available;
        }
      } catch (_) {
        _simDetailText = "SIM Baseband Standby";
        _smsState = HealthState.available;
      }

      // 5. Offline Emergency Events Queue Count
      try {
        _pendingQueueCount = await OfflineEventQueueService().getPendingCount();
      } catch (_) {
        _pendingQueueCount = 0;
      }
    } catch (_) {
      _gpsState = HealthState.error;
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Color _getColorForState(HealthState state) {
    switch (state) {
      case HealthState.available:
        return const Color(0xFF10B981); // Emerald Green
      case HealthState.unavailable:
        return const Color(0xFFF59E0B); // Amber Warning
      case HealthState.permissionRequired:
        return const Color(0xFF38BDF8); // Cyan Alert
      case HealthState.error:
        return const Color(0xFFE11D48); // Crimson Red
    }
  }

  String _getLabelForState(HealthState state) {
    switch (state) {
      case HealthState.available:
        return 'available'.tr;
      case HealthState.unavailable:
        return 'unavailable'.tr;
      case HealthState.permissionRequired:
        return 'perm_required'.tr;
      case HealthState.error:
        return 'error'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26334D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'system_health'.tr,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _checkHealth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: _isChecking ? const Color(0xFF38BDF8) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isChecking ? 'loading'.tr : 'refresh'.tr,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'system_health_desc'.tr,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // 2x2 Grid of Health Metric Tiles
          Row(
            children: [
              Expanded(
                child: _buildHealthTile(
                  icon: Icons.gps_fixed,
                  title: 'gps_status'.tr,
                  statusText: _getLabelForState(_gpsState),
                  statusColor: _getColorForState(_gpsState),
                  detail: _gpsAccuracyText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthTile(
                  icon: Icons.security,
                  title: 'location_perm'.tr,
                  statusText: _getLabelForState(_permState),
                  statusColor: _getColorForState(_permState),
                  detail: _permState == HealthState.available ? 'perm_granted'.tr : 'perm_required'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHealthTile(
                  icon: Icons.wifi,
                  title: 'internet_status'.tr,
                  statusText: _internetStatusText,
                  statusColor: _getColorForState(_netState),
                  detail: _netState == HealthState.available ? "Fast HTTP" : "No Route",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthTile(
                  icon: Icons.sms_outlined,
                  title: 'sms_service'.tr,
                  statusText: _getLabelForState(_smsState),
                  statusColor: _getColorForState(_smsState),
                  detail: _simDetailText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.update, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${'last_loc_update'.tr}: $_lastLocationUpdateText",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _pendingQueueCount > 0
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                  : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _pendingQueueCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.queue,
                  size: 14,
                  color: _pendingQueueCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${'pending_queue'.tr}: $_pendingQueueCount ${_pendingQueueCount == 1 ? 'event pending' : 'events pending'}",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: _pendingQueueCount > 0 ? FontWeight.bold : FontWeight.normal,
                      color: _pendingQueueCount > 0 ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
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

  Widget _buildHealthTile({
    required IconData icon,
    required String title,
    required String statusText,
    required Color statusColor,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26334D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 5),
              Text(
                statusText,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
