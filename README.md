# 🛡️ Accident Guard

> **Smart Accident Detection and Emergency Alert System**

## 📄 Abstract

Accident Guard is a cross-platform telematics and emergency dispatch system developed using Flutter for Android devices. The system utilizes smartphone tri-axial accelerometer streams to continuously monitor vehicle acceleration vectors ($a_x, a_y, a_z$) and combined magnitude ($|\vec{a}| = \sqrt{a_x^2 + a_y^2 + a_z^2}$). Upon detecting acceleration exceeding the validated collision threshold of $35.0\text{ m/s}^2$, the application immediately triggers an audible alarm buzzer and initiates a 30-second safety countdown, allowing uninjured drivers to cancel false alarms via an interactive override. If uncancelled, the autonomous alert pipeline resolves current GPS coordinates with five-decimal precision, queries OpenStreetMap directory servers to identify the three nearest medical facilities and their driving distances, and dispatches multi-channel SOS alerts. Notifications including exact Google Maps location links and critical driver medical data, such as blood group, are transmitted concurrently via Android Native SIM SMS, TextBee HTTP SMS Gateway, and direct SMTP email. Due to standard Android battery management restrictions, continuous real-time accelerometer stream sampling operates while the application is active in the foreground with the screen on, providing an accessible, software-driven life-safety supplementary tool.

---

## ✨ Key Features

- ⚡ **Real-Time 3-Axis Impact Telemetry**: Continuously streams and graphs $a_x$, $a_y$, $a_z$, and total magnitude vectors ($\ge 35.0\text{ m/s}^2$ trigger threshold).
- ⏱️ **Safety Countdown & False-Alarm Override**: Triggers a 30-second audio alarm buzzer allowing drivers to cancel accidental dispatches before alerts are transmitted.
- 🔬 **Activity Test & Calibration Recorder**: Built-in benchmark recorder for measuring real-world phone sensor results across walking, safe phone-drop, simulated braking, simulated potholes, and controlled impacts.
- 🏥 **Nearest Hospital Geocoding (OpenStreetMap)**: Automatically computes distances to registered trauma centers and emergency hubs using high-precision GPS.
- 📡 **Multi-Channel SOS Alerts**:
  - **Direct Device SIM SMS**: Hardware-level native SMS dispatch via Android platform channels (`SmsManager`).
  - **TextBee HTTP SMS Gateway**: REST API gateway fallback for background SMS delivery.
  - **SMTP Emergency Email**: Dispatches structured email notifications to emergency contacts.
  - **Google Maps Navigation**: Direct routing coordinates sent to responders for zero-delay navigation.
- 👥 **Multi-Role Portals**:
  - **🚗 Driver Portal**: Live sensor telemetry, real-time X/Y/Z waveform graph, activity recorder, and alert configuration.
  - **🏥 Hospital Hub**: Live feed of incoming crash dispatches, patient blood group, contact details, and route navigation.
  - **🛡️ Admin Console**: Complete system-wide overview of active drivers, registered hospitals, crash history, and engine state diagnostics.

---

## ⚖️ Factual System Comparison

A concise, factual comparison between **Accident Guard**, **Built-in Smartphone Crash Detection** (Apple / Google Pixel), and **India's 112 Emergency System** (ERSS):

| Evaluation Metric | Built-in Crash Detection (Apple / Pixel) | India 112 Emergency System (ERSS) | Accident Guard System |
|---|---|---|---|
| **Collision Detection Mechanism** | Proprietary multi-sensor fusion (256G accelerometer, HDR gyro, barometer pressure drop, microphone cabin sound). | None on mobile phone. Relies on human voice calls, SMS, or vehicle-mounted AIS-140 GPS tracker panic buttons. | Device-agnostic 3-axis linear accelerometer vector telemetry ($a_x, a_y, a_z$) with a validated $\ge 35.0\text{ m/s}^2$ threshold. |
| **Supported Hardware** | Restricted to high-end flagship smartphones (iPhone 14+, Pixel 3+). | Any mobile phone, landline, or cellular telematics module. | Standard Android smartphones running Flutter. |
| **Primary Notification Channel** | Automated voice call to local Public Safety Answering Point (911/112). | Public Safety Answering Point (PSAP) dispatches local police PCR van or 108 ambulance. | Concurrent Direct Native SIM SMS, TextBee HTTP SMS Gateway, and SMTP Email to personal family contacts. |
| **Driver Medical Data Transfer** | Displays Medical ID on phone lock screen. | Transmitted verbally by caller to 112 operator. | Automatically embeds driver blood group and personal data in digital SMS and email alerts. |
| **Hospital Geocoding** | Not included (transfers to government emergency operator). | Handled by government 108 medical dispatch centre. | Live OpenStreetMap (OSM) spatial geocoding of top 3 nearest trauma facilities with driving distances. |
| **Screen-Off Operation** | Runs 24/7 at low power via dedicated OS-privileged sensor co-processor. | Not applicable (manual call / external vehicle unit). | Requires screen on / app in foreground due to standard Android battery management limits on sensor listeners. |
| **End-User Cost** | Tied to premium hardware ($800+). | Free public government emergency service. | Free, open-source software deployable on any Android phone. |

---

## 📱 Android Background & Screen-Off Telematics

- **Foreground Execution (Screen On)**: The application continuously listens to device accelerometer streams at full frequency and renders real-time X/Y/Z telemetry waveforms.
- **Screen-Off Behavior**: Standard Android OS battery optimization (Doze mode) suspends third-party accelerometer event streams when the phone display is turned off or locked. To maintain continuous crash monitoring during transit, the phone display must remain active or be mounted on a vehicle charger.
- **Dispatch Reliability**: Pre-fetching GPS fixes and executing concurrent multi-channel SMS/Email broadcasts operate reliably as asynchronous platform tasks.

---

## 🔬 Sensor Benchmarks & Activity Scenarios

Accident Guard includes an interactive on-device test recorder for validating sensor behavior across common scenarios:

| Activity Scenario | Typical Acceleration | Expected System Behavior | Verified Outcome |
|---|---|---|---|
| **Walking** | $1.5\text{ – }4.5\text{ m/s}^2$ | Sub-threshold (Safe) | No countdown or false alarm triggered |
| **Safe Phone-Drop (Bed/Sofa)** | $15.0\text{ – }28.0\text{ m/s}^2$ | Sub-threshold (Safe) | Below $35\text{ m/s}^2$ threshold; no false alarm |
| **Simulated Braking** | $8.0\text{ – }18.0\text{ m/s}^2$ | Sub-threshold (Safe) | Longitudinal jerk absorbed without trigger |
| **Simulated Pothole** | $12.0\text{ – }24.0\text{ m/s}^2$ | Sub-threshold (Safe) | Vertical spike filtered as sub-threshold |
| **Controlled Impact** | $\ge 35.0\text{ m/s}^2$ | Threshold Exceeded | Triggers 30s buzzer & safety countdown |

*Note: Sensor recordings must be captured on physical Android hardware using the in-app benchmark recorder.*

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter (Dart 3.x) |
| **State & UI** | Material 3, Custom Glassmorphic Dark UI |
| **Telemetry & Sensors** | `sensors_plus`, `geolocator` |
| **Backend & Cloud** | Google Firebase (Auth & Firestore) + Local Storage Fallback |
| **Alert Protocols** | Android Native Method Channels (SMS), TextBee API, Mailer (SMTP) |
| **Audio Alert** | `flutter_ringtone_player` / Web Audio API |

---

## 📂 Project Structure

```text
accident-guard/
├── android/                   # Native Android host app & MethodChannels
├── ios/                       # iOS configuration
├── web/                       # Web platform support
├── assets/                    # Static assets & icons
└── lib/
    ├── main.dart              # App entry point & theme configuration
    ├── screens/
    │   ├── login_screen.dart          # Multi-role authentication portal
    │   ├── user_registration.dart     # Driver registration & emergency contacts
    │   ├── hospital_registration.dart # Hospital facility registration
    │   ├── control_panel.dart         # Driver hub & alert settings
    │   ├── sensor_monitoring.dart     # Real-time G-force telemetry & crash detector
    │   ├── hospital_dashboard.dart    # Hospital dispatch monitoring
    │   └── admin_dashboard.dart       # Administrator system management
    ├── services/
    │   ├── alert_service.dart         # Multi-channel SMS & Email dispatch logic
    │   ├── database_service.dart      # Hybrid Firestore & offline persistence
    │   ├── hospital_service.dart      # Nearest hospital distance calculations
    │   ├── sensor_service.dart        # Accelerometer stream management
    │   ├── buzzer_service.dart        # Platform-adaptive audio alert service
    │   └── permission_service.dart    # Location, SMS, and sensor permissions
    └── widgets/
        └── emergency_ui_components.dart # Reusable UI cards, buttons, badges
```

---

## 🔑 Demo & Test Accounts

| Role | Email | Password |
|---|---|---|
| **Driver** | `driver@guard.com` *(or register new)* | `Password123!` |
| **Hospital Hub** | `admin@cityemergency.org` | `Password123!` |
| **Administrator** | `shettyprakyathp@gmail.com` | `Password123!` |
| **Administrator (Alt)** | `vaibhava.23cs179@sode-edu.in` | `9731971568` |

---

## 📦 Building Android APK

```bash
flutter build apk --debug
```
The output APK is generated at:
`build/app/outputs/flutter-apk/app-debug.apk`
