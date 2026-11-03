import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';

class EmergencyProfileScreen extends StatefulWidget {
  final String driverEmail;
  const EmergencyProfileScreen({super.key, required this.driverEmail});

  @override
  State<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends State<EmergencyProfileScreen> {
  final DatabaseService _dbService = DatabaseService();

  final _nameController = TextEditingController();
  final _medicalNotesController = TextEditingController();

  String _selectedBloodGroup = 'Unknown';
  bool _consentToShareMedical = false;
  String _parentPhone = '';
  bool _isLoading = true;

  final List<String> _bloodGroups = [
    'Unknown',
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _dbService.getEmergencyProfile(widget.driverEmail);
      if (mounted) {
        setState(() {
          _nameController.text = profile['fullName'] ?? '';
          _selectedBloodGroup = profile['bloodGroup'] ?? 'Unknown';
          if (!_bloodGroups.contains(_selectedBloodGroup)) {
            _selectedBloodGroup = 'Unknown';
          }
          _medicalNotesController.text = profile['medicalNotes'] ?? '';
          _consentToShareMedical = profile['consentToShareMedical'] == true;
          _parentPhone = profile['parentPhone'] ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Driver name cannot be empty."),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    try {
      await _dbService.updateEmergencyProfile(widget.driverEmail, {
        'fullName': name,
        'bloodGroup': _selectedBloodGroup,
        'medicalNotes': _medicalNotesController.text.trim(),
        'consentToShareMedical': _consentToShareMedical,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_saved'.tr),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save profile: $e"),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalization.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'emergency_profile'.tr,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF161E2E), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE11D48).withValues(alpha: 0.18),
                                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.medical_services_outlined, color: Color(0xFFFB7185), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'emergency_profile'.tr,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.driverEmail,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.5,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Basic Details Section
                      SectionHeader(
                        title: 'driver_profile'.tr,
                        subtitle: "Driver identification & emergency dispatch details",
                      ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161E2E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'full_name'.tr,
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Blood Group Selector
                            DropdownButtonFormField<String>(
                              initialValue: _selectedBloodGroup,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'blood_group'.tr,
                                prefixIcon: const Icon(Icons.bloodtype_outlined, color: Color(0xFFFB7185)),
                              ),
                              items: _bloodGroups.map((bg) {
                                return DropdownMenuItem(
                                  value: bg,
                                  child: Text(
                                    bg == 'Unknown' ? 'Unknown / Not specified' : bg,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBloodGroup = val);
                                }
                              },
                            ),
                            if (_parentPhone.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Primary SOS Phone: $_parentPhone",
                                    style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Color(0xFFCBD5E1)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Optional Medical Information Section
                      const SectionHeader(
                        title: "Medical & Health (Optional)",
                        subtitle: "Pre-existing medical conditions, allergies, or medications",
                      ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161E2E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _medicalNotesController,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'medical_notes'.tr,
                                hintText: 'medical_notes_hint'.tr,
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Explicit Consent Switch (Privacy Protection)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _consentToShareMedical
                                      ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.privacy_tip_outlined, size: 18, color: Color(0xFF38BDF8)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'consent_title'.tr,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: _consentToShareMedical,
                                        activeThumbColor: const Color(0xFF38BDF8),
                                        onChanged: (val) {
                                          setState(() => _consentToShareMedical = val);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'consent_desc'.tr,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save CTA
                      InteractivePressable(
                        onTap: _saveProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'save'.tr,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
