import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/emergency_ui_components.dart';
import 'login_screen.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  Map<String, dynamic> get _hospital => _dbService.activeSessionUser ?? {
    'facilityName': 'Main City Hospital (Demo)',
    'email': 'admin@hospital.com',
    'dispatchPhone': '+15005550006',
    'latitude': 12.9716,
    'longitude': 77.5946,
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
    // Auto-refresh the incoming emergency reports queue every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchReports({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final reports = await _dbService.getCrashReports();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      print("HospitalDashboard: Error loading crash reports: $e");
    } finally {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _dispatchResponder(String reportId) async {
    try {
      await _dbService.updateCrashReportStatus(reportId, 'Ambulance Dispatched');
      _fetchReports(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency Ambulance Dispatched & En Route!"),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Action failed: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _logout() {
    _dbService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_hospital_outlined, size: 22, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("Hospital Dispatch Console"),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            tooltip: "Refresh Incidents",
            onPressed: () => _fetchReports(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
            tooltip: "Logout",
            onPressed: _logout,
          )
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0F19), Color(0xFF111827), Color(0xFF161E2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hospital Facility Identity Hero Banner
              FadeSlideTransition(
                duration: const Duration(milliseconds: 320),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF26334D)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                              const Color(0xFF0284C7).withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Center(
                          child: Icon(Icons.local_hospital, color: Color(0xFF38BDF8), size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hospital['facilityName'] ?? "Hospital Emergency Hub",
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Hotline: ${_hospital['dispatchPhone']}  |  GPS: ${_hospital['latitude']}, ${_hospital['longitude']}",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(
                        label: "Dispatch Ready",
                        type: BadgeStatusType.active,
                      ),
                    ],
                  ),
                ),
              ),

              // Headline for alerts queue
              FadeSlideTransition(
                delay: const Duration(milliseconds: 70),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "INCOMING EMERGENCY INCIDENTS",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Text(
                          "${_reports.length} Reports",
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: const Center(
                                child: Icon(Icons.verified_outlined, size: 34, color: Color(0xFF34D399)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No Active Emergency Incidents",
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Live telemetry queue is currently all clear",
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final bool isPending = report['status'] == 'Pending';
                          final String driver = report['driverName'] ?? 'Unknown Driver';
                          final String blood = report['bloodGroup'] ?? 'Unknown';
                          final double lat = report['latitude'] ?? 0.0;
                          final double lng = report['longitude'] ?? 0.0;
                          final String type = report['crashType'] ?? 'Severe Crash';
                          final String time = report['timestamp'] != null
                              ? report['timestamp'].toString().split('.')[0]
                              : 'Now';

                          return FadeSlideTransition(
                            delay: Duration(milliseconds: index * 50),
                            duration: const Duration(milliseconds: 280),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161E2E),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isPending ? const Color(0xFFE11D48).withValues(alpha: 0.45) : const Color(0xFF26334D),
                                  width: isPending ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isPending
                                        ? const Color(0xFFE11D48).withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            if (isPending) ...[
                                              const EmergencyPulseIndicator(size: 14, color: Color(0xFFEF4444)),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: Text(
                                                type,
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPending ? const Color(0xFFFB7185) : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(
                                        label: isPending ? "Pending Dispatch" : "Ambulance En Route",
                                        type: isPending ? BadgeStatusType.critical : BadgeStatusType.active,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Color(0xFF38BDF8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Driver: $driver",
                                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE11D48).withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.35)),
                                        ),
                                        child: Text(
                                          "Blood: $blood",
                                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFB7185)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.my_location, size: 14, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Accident GPS: Lat $lat, Lng $lng",
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Incident Reported: $time",
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white24),
                                  ),
                                  const SizedBox(height: 16),
                                  if (isPending)
                                    InteractivePressable(
                                      onTap: () => _dispatchResponder(report['id']),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.emergency, size: 18, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              "Dispatch Ambulance Responder",
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF34D399)),
                                          SizedBox(width: 8),
                                          Text(
                                            "Ambulance Dispatched & En Route",
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF34D399),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
