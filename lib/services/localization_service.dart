import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language options supported by Accident Guard
enum AppLanguage {
  english('en', 'English'),
  kannada('kn', 'ಕನ್ನಡ'),
  hindi('hi', 'हिन्दी');

  final String code;
  final String displayName;
  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String code) {
    if (code == 'kn') return AppLanguage.kannada;
    if (code == 'hi') return AppLanguage.hindi;
    return AppLanguage.english;
  }
}

/// Global Localization Service for Accident Guard.
/// Provides real-time reactive language switching and persistence via SharedPreferences.
class AppLocalization {
  AppLocalization._();
  static final AppLocalization instance = AppLocalization._();

  static const String _prefKey = 'app_language';
  static AppLanguage _currentLanguage = AppLanguage.english;

  /// ValueNotifier to allow UI components to rebuild reactively on language change
  static final ValueNotifier<AppLanguage> languageNotifier =
      ValueNotifier<AppLanguage>(AppLanguage.english);

  static AppLanguage get currentLanguage => _currentLanguage;
  static bool get isEnglish => _currentLanguage == AppLanguage.english;
  static bool get isKannada => _currentLanguage == AppLanguage.kannada;
  static bool get isHindi => _currentLanguage == AppLanguage.hindi;

  /// Initialize saved language preference
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey) ?? 'en';
      _currentLanguage = AppLanguage.fromCode(savedCode);
      languageNotifier.value = _currentLanguage;
    } catch (_) {}
  }

  /// Change application language
  static Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    languageNotifier.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {}
  }

  /// Translate a string key into the current language
  static String tr(String key) {
    final Map<String, String>? dict = _translations[_currentLanguage.code];
    if (dict != null && dict.containsKey(key)) {
      return dict[key]!;
    }
    // Fallback to English
    return _translations['en']?[key] ?? key;
  }

  // Master translation dictionary
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // App & Common
      'app_title': 'Accident Guard',
      'tagline': 'Smart Accident Detection & Emergency Response System',
      'driver_hub': 'Driver Protection Hub',
      'driver_profile': 'Driver Profile',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'clear': 'Clear',
      'refresh': 'Refresh',
      'status': 'Status',
      'details': 'Details',
      'back': 'Back',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirm': 'Confirm',
      'view_map': 'View on Google Maps',
      'active': 'Active',
      'standby': 'Standby',
      'online': 'Online',
      'offline': 'Offline',

      // Navigation & Sections
      'telematics': 'Crash Telematics',
      'launch_telematics': 'Launch Crash Telematics',
      'launch_telematics_desc': 'Continuous G-force monitoring & live crash trigger',
      'emergency_contacts': 'Emergency Contacts',
      'emergency_contacts_desc': 'Manage multi-contact emergency alert recipients',
      'accident_history': 'Accident History',
      'accident_history_desc': 'View chronological incident logs & dispatch status',
      'emergency_profile': 'Emergency Profile',
      'emergency_profile_desc': 'Manage driver blood group & medical information',
      'offline_maps': 'Offline Maps & Hospitals',
      'offline_maps_desc': 'Access cached hospital database & navigation offline',
      'settings': 'System Settings',
      'settings_desc': 'Configure countdown timers, gateways & application language',
      'app_language': 'App Language',
      'countdown_duration': 'SOS Countdown Duration',
      'seconds': 'seconds',

      // Feature 1: Emergency SOS Countdown & Manual SOS
      'manual_sos': 'Manual Emergency SOS',
      'manual_sos_desc': 'Trigger immediate emergency broadcast without waiting for crash',
      'manual_sos_confirm': 'Are you sure you want to trigger an immediate Emergency SOS?',
      'accident_detected': 'ACCIDENT DETECTED',
      'critical_impact': 'Critical Collision Force Detected',
      'countdown_prompt': 'Automated emergency alert dispatching in:',
      'i_am_safe': 'I AM SAFE (CANCEL)',
      'send_immediately': 'SEND IMMEDIATELY (BYPASS)',
      'alert_cancelled': 'Emergency cancelled: Driver confirmed safe.',
      'alert_dispatched': 'Emergency alert broadcasted to contacts and hospital.',
      'buzzer_active': 'Warning buzzer active. Tap I AM SAFE if uninjured.',

      // Feature 2: Emergency Contacts
      'add_contact': 'Add Emergency Contact',
      'edit_contact': 'Edit Contact',
      'delete_contact_title': 'Delete Emergency Contact?',
      'delete_contact_confirm': 'Are you sure you want to remove this contact from emergency alerts?',
      'primary_contact': 'Primary Contact',
      'make_primary': 'Set as Primary Emergency Contact',
      'contact_name': 'Contact Name',
      'contact_phone': 'Mobile Number',
      'contact_relation': 'Relationship (Optional)',
      'receive_alerts': 'Receive SMS Alerts',
      'receive_alerts_desc': 'Include this contact in emergency SMS broadcasts',
      'invalid_phone': 'Please enter a valid 10-digit Indian mobile number',
      'duplicate_phone': 'This mobile number is already added as an emergency contact',
      'no_contacts': 'No emergency contacts found. Add trusted family or friends.',
      'contact_added': 'Emergency contact added successfully',
      'contact_updated': 'Emergency contact updated',
      'contact_deleted': 'Emergency contact deleted',

      // Feature 3 & 5: Live GPS & Retry System
      'emergency_status': 'Emergency Status',
      'gps_coordinates': 'GPS Coordinates',
      'gps_accuracy': 'GPS Accuracy',
      'gps_freshness': 'Location Freshness',
      'location_stale': 'Stale Location (Over 5 mins old)',
      'last_known_location': 'Last Known Location (Offline)',
      'sms_pending': 'Pending Dispatch',
      'sms_sent': 'Submitted (Cell Tower Accepted)',
      'sms_delivered': 'Delivered (Handset Confirmed)',
      'sms_failed': 'Dispatch Failed',
      'sms_retrying': 'Retrying SMS Dispatch...',
      'retry_attempt': 'Attempt',
      'hospital_notification': 'Hospital Notification',
      'hospital_notified': 'Hospital Notified',
      'hospital_pending': 'Hospital Lookup Pending',
      'hospital_unavailable': 'No Nearby Hospital Available',

      // Feature 4: Accident History
      'history_title': 'Accident Incident Logs',
      'history_subtitle': 'Chronological audit trail of all detected collision events',
      'filter_all': 'All',
      'filter_dispatched': 'Dispatched',
      'filter_cancelled': 'Cancelled (Safe)',
      'filter_failed': 'Failed',
      'clear_history': 'Clear History',
      'clear_history_confirm': 'Are you sure you want to clear all accident history logs? This action cannot be undone.',
      'no_history': 'No accident incidents recorded yet.',
      'event_details': 'Incident Details',
      'max_force': 'Peak Force',
      'crash_type': 'Collision Classification',
      'dispatch_summary': 'Dispatch Summary',

      // Feature 5: Offline Map & Cached Hospitals
      'cached_hospitals': 'Cached Emergency Hospitals',
      'download_cache': 'Download Regional Offline Cache',
      'cache_updated': 'Hospital offline cache updated successfully!',
      'live_data': 'LIVE OSM DATA',
      'cached_data': 'CACHED / OFFLINE DATA',
      'distance_km': 'km away',
      'call_hospital': 'Call Facility',
      'navigate': 'Navigate (Google Maps)',
      'no_cached_hospitals': 'No cached hospitals found. Tap Download to cache local hospitals.',

      // Feature 6 & 8: Health Monitor & Offline Queues
      'gps_status': 'GPS Hardware',
      'location_perm': 'Location Permission',
      'internet_status': 'Internet Connection',
      'cellular_status': 'Cellular & SIM Service',
      'sms_service': 'Direct SIM SMS',
      'last_loc_update': 'Last GPS Fix',
      'perm_granted': 'Granted',
      'perm_required': 'Permission Required',
      'perm_denied': 'Denied Forever',
      'available': 'Available',
      'unavailable': 'Unavailable',
      'sim_ready': 'SIM Ready (Cellular Active)',
      'sim_no_service': 'No Cellular Signal / Offline',
      'pending_queue': 'Pending Offline Alerts',
      'queued_alerts': 'Queued for Retry',
      'retry_now': 'Process Queue Now',

      // Feature 8: Emergency Profile
      'full_name': 'Full Name',
      'blood_group': 'Blood Group',
      'medical_notes': 'Emergency Medical Notes (Optional)',
      'medical_notes_hint': 'Allergies, chronic conditions, medications...',
      'consent_title': 'Medical Privacy Consent',
      'consent_desc': 'Explicitly permit including blood group and medical notes in emergency alert broadcasts to contacts and hospitals.',
      'profile_saved': 'Emergency profile updated successfully',

      // Sensor Monitoring Screen
      'start_telematics': 'Start Monitoring',
      'stop_telematics': 'Stop Monitoring',
      'sim_crash': 'Simulate Crash Vectors',
      'frontal': 'Frontal Collision',
      'lateral': 'Side Impact (Lateral)',
      'rollover': 'Rollover / Vertical',
      'current_force': 'Current Force',
      'peak_force_gauge': 'Peak Force',
    },

    'kn': {
      // App & Common
      'app_title': 'ಆಕ್ಸಿಡೆಂಟ್ ಗಾರ್ಡ್',
      'tagline': 'ಸ್ಮಾರ್ಟ್ ಅಪಘಾತ ಪತ್ತೆ ಮತ್ತು ತುರ್ತು ಪ್ರತಿಕ್ರಿಯೆ ವ್ಯವಸ್ಥೆ',
      'driver_hub': 'ಚಾಲಕರ ರಕ್ಷಣಾ ಕೇಂದ್ರ',
      'driver_profile': 'ಚಾಲಕರ ಪ್ರೊಫೈಲ್',
      'save': 'ಉಳಿಸಿ',
      'cancel': 'ರದ್ದುಗೊಳಿಸಿ',
      'delete': 'ಅಳಿಸಿ',
      'edit': 'ತಿದ್ದುಪಡಿ',
      'clear': 'ತೆರವುಗೊಳಿಸಿ',
      'refresh': 'ನವೀಕರಿಸಿ',
      'status': 'ಸ್ಥಿತಿ',
      'details': 'ವಿವರಗಳು',
      'back': 'ಹಿಂದಕ್ಕೆ',
      'loading': 'ಲೋಡ್ ಆಗುತ್ತಿದೆ...',
      'error': 'ದೋಷ',
      'success': 'ಯಶಸ್ಸು',
      'confirm': 'ಖಚಿತಪಡಿಸಿ',
      'view_map': 'ಗೂಗಲ್ ಮ್ಯಾಪ್‌ನಲ್ಲಿ ವೀಕ್ಷಿಸಿ',
      'active': 'ಸಕ್ರಿಯ',
      'standby': 'ಸ್ಟ್ಯಾಂಡ್‌ಬೈ',
      'online': 'ಆನ್‌ಲೈನ್',
      'offline': 'ಆಫ್‌ಲೈನ್',

      // Navigation & Sections
      'telematics': 'ಅಪಘಾತ ಟೆಲಿಮ್ಯಾಟಿಕ್ಸ್',
      'launch_telematics': 'ಟೆಲಿಮ್ಯಾಟಿಕ್ಸ್ ಪ್ರಾರಂಭಿಸಿ',
      'launch_telematics_desc': 'ನಿರಂತರ ಜಿ-ಫೋರ್ಸ್ ಮಾನಿಟರಿಂಗ್ ಮತ್ತು ಅಪಘಾತ ಪತ್ತೆ',
      'emergency_contacts': 'ತುರ್ತು ಸಂಪರ್ಕಗಳು',
      'emergency_contacts_desc': 'ತುರ್ತು ಸಂದೇಶ ಪಡೆಯುವ ಸಂಪರ್ಕಗಳನ್ನು ನಿರ್ವಹಿಸಿ',
      'accident_history': 'ಅಪಘಾತ ಇತಿಹಾಸ',
      'accident_history_desc': 'ಪತ್ತೆಯಾದ ಅಪಘಾತ ಘಟನೆಗಳ ದಾಖಲೆಗಳನ್ನು ವೀಕ್ಷಿಸಿ',
      'emergency_profile': 'ತುರ್ತು ಪ್ರೊಫೈಲ್',
      'emergency_profile_desc': 'ರಕ್ತದ ಗುಂಪು ಮತ್ತು ವೈದ್ಯಕೀಯ ಮಾಹಿತಿಯನ್ನು ನಿರ್ವಹಿಸಿ',
      'offline_maps': 'ಆಫ್‌ಲೈನ್ ನಕ್ಷೆ ಮತ್ತು ಆಸ್ಪತ್ರೆಗಳು',
      'offline_maps_desc': 'ಆಫ್‌ಲೈನ್ ಆಸ್ಪತ್ರೆಗಳ ಡೇಟಾಬೇಸ್ ಮತ್ತು ನ್ಯಾವಿಗೇಷನ್ ಪ್ರವೇಶಿಸಿ',
      'settings': 'ಸಿಸ್ಟಮ್ ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
      'settings_desc': 'ಕೌಂಟ್‌ಡೌನ್ ಸಮಯ ಮತ್ತು ಅಪ್ಲಿಕೇಶನ್ ಭಾಷೆಯನ್ನು ಕಾನ್ಫಿಗರ್ ಮಾಡಿ',
      'app_language': 'ಅಪ್ಲಿಕೇಶನ್ ಭಾಷೆ',
      'countdown_duration': 'ಎಸ್ಒಎಸ್ ಕೌಂಟ್‌ಡೌನ್ ಅವಧಿ',
      'seconds': 'ಸೆಕೆಂಡುಗಳು',

      // Feature 1: Emergency SOS Countdown & Manual SOS
      'manual_sos': 'ಹಸ್ತಚಾಲಿತ ತುರ್ತು ಎಸ್ಒಎಸ್',
      'manual_sos_desc': 'ಅಪಘಾತ ಕಾಯದೆ ತಕ್ಷಣ ತುರ್ತು ಸಂದೇಶ ಕಳುಹಿಸಿ',
      'manual_sos_confirm': 'ನೀವು ತಕ್ಷಣ ತುರ್ತು ಎಸ್ಒಎಸ್ ಪ್ರಸಾರ ಮಾಡಲು ಖಚಿತವಾಗಿದ್ದೀರಾ?',
      'accident_detected': 'ಅಪಘಾತ ಪತ್ತೆಯಾಗಿದೆ',
      'critical_impact': 'ತೀವ್ರ ಅಪಘಾತ ಡಿಕ್ಕಿ ಪತ್ತೆಯಾಗಿದೆ',
      'countdown_prompt': 'ಸ್ವಯಂಚಾಲಿತ ತುರ್ತು ಪ್ರಸಾರ ಇನ್ನು:',
      'i_am_safe': 'ನಾನು ಸುರಕ್ಷಿತವಾಗಿದ್ದೇನೆ (ರದ್ದುಗೊಳಿಸಿ)',
      'send_immediately': 'ತಕ್ಷಣ ಕಳುಹಿಸಿ (ಸಮಯ ಬೈಪಾಸ್)',
      'alert_cancelled': 'ತುರ್ತು ರದ್ದುಗೊಂಡಿದೆ: ಚಾಲಕ ಸುರಕ್ಷಿತವಾಗಿದ್ದಾರೆ.',
      'alert_dispatched': 'ತುರ್ತು ಸಂದೇಶವನ್ನು ಸಂಪರ್ಕಗಳಿಗೆ ಮತ್ತು ಆಸ್ಪತ್ರೆಗೆ ಕಳುಹಿಸಲಾಗಿದೆ.',
      'buzzer_active': 'ಎಚ್ಚರಿಕೆ ಶಬ್ದ ಸಕ್ರಿಯವಾಗಿದೆ. ಸುರಕ್ಷಿತವಾಗಿದ್ದರೆ ರದ್ದುಗೊಳಿಸಿ.',

      // Feature 2: Emergency Contacts
      'add_contact': 'ತುರ್ತು ಸಂಪರ್ಕ ಸೇರಿಸಿ',
      'edit_contact': 'ಸಂಪರ್ಕ ತಿದ್ದುಪಡಿ',
      'delete_contact_title': 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಅಳಿಸುವುದೇ?',
      'delete_contact_confirm': 'ಈ ಸಂಪರ್ಕವನ್ನು ತುರ್ತು ಎಚ್ಚರಿಕೆಯಿಂದ ತೆಗೆದುಹಾಕಲು ಖಚಿತಪಡಿಸಿ.',
      'primary_contact': 'ಮುಖ್ಯ ಸಂಪರ್ಕ',
      'make_primary': 'ಮುಖ್ಯ ಸಂಪರ್ಕವಾಗಿ ಹೊಂದಿಸಿ',
      'contact_name': 'ಸಂಪರ್ಕ ಹೆಸರು',
      'contact_phone': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
      'contact_relation': 'ಸಂಬಂಧ (ಐಚ್ಛಿಕ)',
      'receive_alerts': 'ಎಸ್ಎಂಎಸ್ ಎಚ್ಚರಿಕೆಗಳನ್ನು ಪಡೆಯಿರಿ',
      'receive_alerts_desc': 'ತುರ್ತು ಸಂದೇಶ ಪ್ರಸಾರದಲ್ಲಿ ಈ ಸಂಪರ್ಕವನ್ನು ಸೇರಿಸಿ',
      'invalid_phone': 'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10-ಅಂಕಿಯ ಭಾರತೀಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
      'duplicate_phone': 'ಈ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಈಗಾಗಲೇ ತುರ್ತು ಸಂಪರ್ಕವಾಗಿ ನೋಂದಾಯಿಸಲ್ಪಟ್ಟಿದೆ',
      'no_contacts': 'ಯಾವುದೇ ತುರ್ತು ಸಂಪರ್ಕಗಳನ್ನು ಸೇರಿಸಲಾಗಿಲ್ಲ. ವಿಶ್ವಾಸಾರ್ಹ ಸಂಪರ್ಕಗಳನ್ನು ಸೇರಿಸಿ.',
      'contact_added': 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸೇರಿಸಲಾಗಿದೆ',
      'contact_updated': 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ',
      'contact_deleted': 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಅಳಿಸಲಾಗಿದೆ',

      // Feature 3 & 5: Live GPS & Retry System
      'emergency_status': 'ತುರ್ತು ಸ್ಥಿತಿ',
      'gps_coordinates': 'ಜಿಪಿಎಸ್ ನಿರ್ದೇಶಾಂಕಗಳು',
      'gps_accuracy': 'ಜಿಪಿಎಸ್ ನಿಖರತೆ',
      'gps_freshness': 'ಸ್ಥಳದ ತಾಜಾತನ',
      'location_stale': 'ಹಳೆಯ ಸ್ಥಳ (5 ನಿಮಿಷಗಳಿಗಿಂತ ಹಳೆಯದು)',
      'last_known_location': 'ಕೊನೆಯದಾಗಿ ತಿಳಿದ ಸ್ಥಳ (ಆಫ್‌ಲೈನ್)',
      'sms_pending': 'ಬಾಕಿ ಇದೆ',
      'sms_sent': 'ಕಳುಹಿಸಲಾಗಿದೆ (ಸೆಲ್ ಟವರ್ ಸ್ವೀಕರಿಸಿದೆ)',
      'sms_delivered': 'ತಲುಪಿಸಲಾಗಿದೆ (ದೃಢೀಕರಿಸಲಾಗಿದೆ)',
      'sms_failed': 'ವಿಫಲವಾಗಿದೆ',
      'sms_retrying': 'ಎಸ್ಎಂಎಸ್ ಮರುಪ್ರಯತ್ನಿಸಲಾಗುತ್ತಿದೆ...',
      'retry_attempt': 'ಪ್ರಯತ್ನ',
      'hospital_notification': 'ಆಸ್ಪತ್ರೆ ಅಧಿಸೂಚನೆ',
      'hospital_notified': 'ಆಸ್ಪತ್ರೆಗೆ ತಿಳಿಸಲಾಗಿದೆ',
      'hospital_pending': 'ಆಸ್ಪತ್ರೆ ಹುಡುಕಾಟ ಬಾಕಿ ಇದೆ',
      'hospital_unavailable': 'ಹತ್ತಿರದ ಆಸ್ಪತ್ರೆ ಲಭ್ಯವಿಲ್ಲ',

      // Feature 4: Accident History
      'history_title': 'ಅಪಘಾತ ಘಟನೆ ದಾಖಲೆಗಳು',
      'history_subtitle': 'ಎಲ್ಲಾ ಪತ್ತೆಯಾದ ಅಪಘಾತ ಘಟನೆಗಳ ಕಾಲಾನುಕ್ರಮದ ದಾಖಲೆಗಳು',
      'filter_all': 'ಎಲ್ಲವೂ',
      'filter_dispatched': 'ಕಳುಹಿಸಲಾಗಿದೆ',
      'filter_cancelled': 'ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ (ಸುರಕ್ಷಿತ)',
      'filter_failed': 'ವಿಫಲವಾಗಿದೆ',
      'clear_history': 'ಇತಿಹಾಸ ತೆರವುಗೊಳಿಸಿ',
      'clear_history_confirm': 'ಎಲ್ಲಾ ಅಪಘಾತ ಇತಿಹಾಸ ದಾಖಲೆಗಳನ್ನು ಅಳಿಸಲು ನೀವು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಇದನ್ನು ರದ್ದುಮಾಡಲಾಗುವುದಿಲ್ಲ.',
      'no_history': 'ಯಾವುದೇ ಅಪಘಾತ ಘಟನೆಗಳು ದಾಖಲಾಗಿಲ್ಲ.',
      'event_details': 'ಘಟನೆ ವಿವರಗಳು',
      'max_force': 'ಗರಿಷ್ಠ ಬಲ',
      'crash_type': 'ಅಪಘಾತದ ಪ್ರಕಾರ',
      'dispatch_summary': 'ರವಾನೆ ಸಾರಾಂಶ',

      // Feature 5: Offline Map & Cached Hospitals
      'cached_hospitals': 'ಕ್ಯಾಶ್ ಮಾಡಿದ ತುರ್ತು ಆಸ್ಪತ್ರೆಗಳು',
      'download_cache': 'ಪ್ರಾದೇಶಿಕ ಆಫ್‌ಲೈನ್ ಡೇಟಾ ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ',
      'cache_updated': 'ಆಸ್ಪತ್ರೆ ಆಫ್‌ಲೈನ್ ಕ್ಯಾಶ್ ಯಶಸ್ವಿಯಾಗಿ ನವೀಕರಿಸಲಾಗಿದೆ!',
      'live_data': 'ಲೈವ್ ಓಎಸ್‌ಎಂ ಡೇಟಾ',
      'cached_data': 'ಕ್ಯಾಶ್ ಮಾಡಿದ ಆಫ್‌ಲೈನ್ ಡೇಟಾ',
      'distance_km': 'ಕಿ.ಮೀ ದೂರದಲ್ಲಿದೆ',
      'call_hospital': 'ಆಸ್ಪತ್ರೆಗೆ ಕರೆ ಮಾಡಿ',
      'navigate': 'ನ್ಯಾವಿಗೇಷನ್ (ಗೂಗಲ್ ಮ್ಯಾಪ್ಸ್)',
      'no_cached_hospitals': 'ಕ್ಯಾಶ್ ಮಾಡಿದ ಆಸ್ಪತ್ರೆಗಳು ಕಂಡುಬಂದಿಲ್ಲ. ಡೌನ್‌ಲೋಡ್ ಒತ್ತಿರಿ.',

      // Feature 6 & 8: Health Monitor & Offline Queues
      'gps_status': 'ಜಿಪಿಎಸ್ ಯಂತ್ರಾಂಶ',
      'location_perm': 'ಸ್ಥಳ ಅನುಮತಿ',
      'internet_status': 'ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕ',
      'cellular_status': 'ಸೆಲ್ಯುಲಾರ್ ಮತ್ತು ಸಿಮ್ ಸೇವೆ',
      'sms_service': 'ನೇರ ಸಿಮ್ ಎಸ್ಎಂಎಸ್',
      'last_loc_update': 'ಕೊನೆಯ ಜಿಪಿಎಸ್ ನವೀಕರಣ',
      'perm_granted': 'ನೀಡಲಾಗಿದೆ',
      'perm_required': 'ಅನುಮತಿ ಅಗತ್ಯವಿದೆ',
      'perm_denied': 'ಶಾಶ್ವತವಾಗಿ ನಿರಾಕರಿಸಲಾಗಿದೆ',
      'available': 'ಲಭ್ಯವಿದೆ',
      'unavailable': 'ಲಭ್ಯವಿಲ್ಲ',
      'sim_ready': 'ಸಿಮ್ ಸಿದ್ಧವಾಗಿದೆ (ಸೆಲ್ಯುಲಾರ್ ಸಕ್ರಿಯ)',
      'sim_no_service': 'ಸಿಗ್ನಲ್ ಇಲ್ಲ / ಆಫ್‌ಲೈನ್',
      'pending_queue': 'ಬಾಕಿ ಉಳಿದ ಆಫ್‌ಲೈನ್ ಎಚ್ಚರಿಕೆಗಳು',
      'queued_alerts': 'ಮರುಪ್ರಯತ್ನಕ್ಕಾಗಿ ಕಾಯುತ್ತಿದೆ',
      'retry_now': 'ಈಗಲೇ ಕಳುಹಿಸಿ',

      // Feature 8: Emergency Profile
      'full_name': 'ಪೂರ್ಣ ಹೆಸರು',
      'blood_group': 'ರಕ್ತದ ಗುಂಪು',
      'medical_notes': 'ತುರ್ತು ವೈದ್ಯಕೀಯ ಮಾಹಿತಿ (ಐಚ್ಛಿಕ)',
      'medical_notes_hint': 'ಅಲರ್ಜಿಗಳು, ದೀರ್ಘಕಾಲದ ಕಾಯಿಲೆಗಳು, ಔಷಧಗಳು...',
      'consent_title': 'ವೈದ್ಯಕೀಯ ಮಾಹಿತಿ ಹಂಚಿಕೆ ಅನುಮತಿ',
      'consent_desc': 'ತುರ್ತು ಸಂದರ್ಭದಲ್ಲಿ ರಕ್ತದ ಗುಂಪು ಮತ್ತು ವೈದ್ಯಕೀಯ ಮಾಹಿತಿಯನ್ನು ಸಂಪರ್ಕಗಳು ಮತ್ತು ಆಸ್ಪತ್ರೆಗಳಿಗೆ ಕಳುಹಿಸಲು ಅನುಮತಿಸಿ.',
      'profile_saved': 'ತುರ್ತು ಪ್ರೊಫೈಲ್ ಯಶಸ್ವಿಯಾಗಿ ನವೀಕರಿಸಲಾಗಿದೆ',

      // Sensor Monitoring Screen
      'start_telematics': 'ಮಾನಿಟರಿಂಗ್ ಪ್ರಾರಂಭಿಸಿ',
      'stop_telematics': 'ಮಾನಿಟರಿಂಗ್ ನಿಲ್ಲಿಸಿ',
      'sim_crash': 'ಅಪಘಾತ ವೆಕ್ಟರ್‌ಗಳನ್ನು ಅನುಕರಿಸಿ',
      'frontal': 'ಮುಂಭಾಗದ ಡಿಕ್ಕಿ',
      'lateral': 'ಪಾರ್ಶ್ವ ಡಿಕ್ಕಿ',
      'rollover': 'ವಾಹನ ಪಲ್ಟಿ',
      'current_force': 'ಪ್ರಸ್ತುತ ಬಲ',
      'peak_force_gauge': 'ಗರಿಷ್ಠ ಬಲ',
    },

    'hi': {
      // App & Common
      'app_title': 'एक्सीडेंट गार्ड',
      'tagline': 'स्मार्ट दुर्घटना पहचान एवं आपातकालीन प्रतिक्रिया प्रणाली',
      'driver_hub': 'ड्राइवर सुरक्षा हब',
      'driver_profile': 'ड्राइवर प्रोफ़ाइल',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'clear': 'साफ़ करें',
      'refresh': 'ताज़ा करें',
      'status': 'स्थिति',
      'details': 'विवरण',
      'back': 'वापस',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'success': 'सफल',
      'confirm': 'पुष्टि करें',
      'view_map': 'गूगल मैप्स पर देखें',
      'active': 'सक्रिय',
      'standby': 'स्टैंडबाय',
      'online': 'ऑनलाइन',
      'offline': 'ऑफ़लाइन',

      // Navigation & Sections
      'telematics': 'क्रैश टेलीमैटिक्स',
      'launch_telematics': 'क्रैश टेलीमैटिक्स शुरू करें',
      'launch_telematics_desc': 'निरंतर जी-फोर्स निगरानी और लाइव क्रैश डिटेक्शन',
      'emergency_contacts': 'आपातकालीन संपर्क',
      'emergency_contacts_desc': 'आपातकालीन अलर्ट प्राप्तकर्ताओं को प्रबंधित करें',
      'accident_history': 'दुर्घटना इतिहास',
      'accident_history_desc': 'दुर्घटना घटनाओं के कालानुक्रमिक लॉग और प्रेषण स्थिति देखें',
      'emergency_profile': 'आपातकालीन प्रोफ़ाइल',
      'emergency_profile_desc': 'रक्त समूह और महत्वपूर्ण चिकित्सा जानकारी प्रबंधित करें',
      'offline_maps': 'ऑफ़लाइन मानचित्र एवं अस्पताल',
      'offline_maps_desc': 'ऑफ़लाइन अस्पताल डेटाबेस और नेविगेशन तक पहुंचें',
      'settings': 'सिस्टम सेटिंग्स',
      'settings_desc': 'काउंटडाउन समय, गेटवे और एप्लिकेशन भाषा कॉन्फ़िगर करें',
      'app_language': 'ऐप की भाषा',
      'countdown_duration': 'एसओएस काउंटडाउन अवधि',
      'seconds': 'सेकंड',

      // Feature 1: Emergency SOS Countdown & Manual SOS
      'manual_sos': 'मैन्युअल आपातकालीन एसओएस',
      'manual_sos_desc': 'दुर्घटना की प्रतीक्षा किए बिना तत्काल आपातकालीन अलर्ट भेजें',
      'manual_sos_confirm': 'क्या आप वाकई तत्काल आपातकालीन एसओएस अलर्ट भेजना चाहते हैं?',
      'accident_detected': 'दुर्घटना का पता चला',
      'critical_impact': 'गंभीर टकराव बल का पता चला',
      'countdown_prompt': 'स्वचालित आपातकालीन अलर्ट प्रेषण में शेष समय:',
      'i_am_safe': 'मैं सुरक्षित हूँ (रद्द करें)',
      'send_immediately': 'तुरंत भेजें (समय बाईपास)',
      'alert_cancelled': 'आपातकाल रद्द: ड्राइवर सुरक्षित है।',
      'alert_dispatched': 'आपातकालीन अलर्ट संपर्कों और अस्पताल को भेज दिया गया है।',
      'buzzer_active': 'चेतावनी बजर सक्रिय है। सुरक्षित होने पर रद्द करें दबाएं।',

      // Feature 2: Emergency Contacts
      'add_contact': 'आपातकालीन संपर्क जोड़ें',
      'edit_contact': 'संपर्क संपादित करें',
      'delete_contact_title': 'आपातकालीन संपर्क हटाएं?',
      'delete_contact_confirm': 'क्या आप वाकई इस संपर्क को आपातकालीन अलर्ट से हटाना चाहते हैं?',
      'primary_contact': 'प्राथमिक संपर्क',
      'make_primary': 'प्राथमिक आपातकालीन संपर्क बनाएं',
      'contact_name': 'संपर्क नाम',
      'contact_phone': 'मोबाइल नंबर',
      'contact_relation': 'संबंध (वैकल्पिक)',
      'receive_alerts': 'एसएमएस अलर्ट प्राप्त करें',
      'receive_alerts_desc': 'आपातकालीन एसएमएस प्रसारण में इस संपर्क को शामिल करें',
      'invalid_phone': 'कृपया एक मान्य 10-अंकीय भारतीय मोबाइल नंबर दर्ज करें',
      'duplicate_phone': 'यह मोबाइल नंबर पहले से ही आपातकालीन संपर्क के रूप में मौजूद है',
      'no_contacts': 'कोई आपातकालीन संपर्क नहीं मिला। विश्वसनीय संपर्क जोड़ें।',
      'contact_added': 'आपातकालीन संपर्क सफलतापूर्वक जोड़ा गया',
      'contact_updated': 'आपातकालीन संपर्क अपडेट किया गया',
      'contact_deleted': 'आपातकालीन संपर्क हटा दिया गया',

      // Feature 3 & 5: Live GPS & Retry System
      'emergency_status': 'आपातकालीन स्थिति',
      'gps_coordinates': 'जीपीएस निर्देशांक',
      'gps_accuracy': 'जीपीएस सटीकता',
      'gps_freshness': 'स्थान की ताजगी',
      'location_stale': 'पुराना स्थान (5 मिनट से अधिक पुराना)',
      'last_known_location': 'अंतिम ज्ञात स्थान (ऑफ़लाइन)',
      'sms_pending': 'प्रेषण लंबित',
      'sms_sent': 'भेजा गया (सेल टॉवर द्वारा स्वीकृत)',
      'sms_delivered': 'वितरित (हैंडसेट द्वारा पुष्ट)',
      'sms_failed': 'प्रेषण विफल',
      'sms_retrying': 'एसएमएस पुनः प्रयास किया जा रहा है...',
      'retry_attempt': 'प्रयास',
      'hospital_notification': 'अस्पताल अधिसूचना',
      'hospital_notified': 'अस्पताल को सूचित किया गया',
      'hospital_pending': 'अस्पताल खोज लंबित',
      'hospital_unavailable': 'निकटतम अस्पताल उपलब्ध नहीं है',

      // Feature 4: Accident History
      'history_title': 'दुर्घटना घटना लॉग',
      'history_subtitle': 'पहचानी गई सभी दुर्घटना घटनाओं का कालानुक्रमिक रिकॉर्ड',
      'filter_all': 'सभी',
      'filter_dispatched': 'भेजे गए',
      'filter_cancelled': 'रद्द (सुरक्षित)',
      'filter_failed': 'विफल',
      'clear_history': 'इतिहास साफ़ करें',
      'clear_history_confirm': 'क्या आप सभी दुर्घटना इतिहास लॉग साफ़ करना चाहते हैं? इसे पूर्ववत नहीं किया जा सकता।',
      'no_history': 'अभी तक कोई दुर्घटना दर्ज नहीं हुई है।',
      'event_details': 'घटना विवरण',
      'max_force': 'चरम बल',
      'crash_type': 'टक्कर वर्गीकरण',
      'dispatch_summary': 'प्रेषण सारांश',

      // Feature 5: Offline Map & Cached Hospitals
      'cached_hospitals': 'कैश किए गए आपातकालीन अस्पताल',
      'download_cache': 'क्षेत्रीय ऑफ़लाइन डेटा डाउनलोड करें',
      'cache_updated': 'अस्पताल ऑफ़लाइन कैश सफलतापूर्वक अपडेट हुआ!',
      'live_data': 'लाइव ओएसएम डेटा',
      'cached_data': 'कैश किया गया / ऑफ़लाइन डेटा',
      'distance_km': 'किमी दूर',
      'call_hospital': 'अस्पताल को कॉल करें',
      'navigate': 'नेविगेट करें (गूगल मैप्स)',
      'no_cached_hospitals': 'कोई कैश किया गया अस्पताल नहीं मिला। डाउनलोड पर टैप करें।',

      // Feature 6 & 8: Health Monitor & Offline Queues
      'gps_status': 'जीपीएस हार्डवेयर',
      'location_perm': 'स्थान अनुमति',
      'internet_status': 'इंटरनेट कनेक्शन',
      'cellular_status': 'सेलुलर एवं सिम सेवा',
      'sms_service': 'प्रत्यक्ष सिम एसएमएस',
      'last_loc_update': 'अंतिम जीपीएस अपडेट',
      'perm_granted': 'अनुमति दी गई',
      'perm_required': 'अनुमति आवश्यक है',
      'perm_denied': 'स्थायी रूप से अस्वीकृत',
      'available': 'उपलब्ध',
      'unavailable': 'अनुपलब्ध',
      'sim_ready': 'सिम तैयार (सेलुलर सक्रिय)',
      'sim_no_service': 'कोई सेलुलर सिग्नल नहीं / ऑफ़लाइन',
      'pending_queue': 'लंबित ऑफ़लाइन अलर्ट',
      'queued_alerts': 'पुनः प्रयास के लिए कतारबद्ध',
      'retry_now': 'अभी कतार संसाधित करें',

      // Feature 8: Emergency Profile
      'full_name': 'पूरा नाम',
      'blood_group': 'रक्त समूह',
      'medical_notes': 'आपातकालीन चिकित्सा नोट्स (वैकल्पिक)',
      'medical_notes_hint': 'एलर्जी, पुरानी बीमारियाँ, दवाएं...',
      'consent_title': 'चिकित्सा गोपनीयता सहमति',
      'consent_desc': 'आपातकालीन अलर्ट में रक्त समूह और चिकित्सा नोट्स को संपर्कों और अस्पतालों के साथ साझा करने की स्पष्ट अनुमति दें।',
      'profile_saved': 'आपातकालीन प्रोफ़ाइल सफलतापूर्वक अपडेट की गई',

      // Sensor Monitoring Screen
      'start_telematics': 'निगरानी शुरू करें',
      'stop_telematics': 'निगरानी रोकें',
      'sim_crash': 'क्रैश वैक्टर का अनुकरण करें',
      'frontal': 'सामने से टक्कर',
      'lateral': 'पार्श्व टक्कर (साइड इम्पैक्ट)',
      'rollover': 'वाहन पलटना (रोलओवर)',
      'current_force': 'वर्तमान बल',
      'peak_force_gauge': 'चरम बल',
    },
  };
}

/// Extension for convenient string translation
extension StringLocalizationExtension on String {
  String get tr => AppLocalization.tr(this);
}
