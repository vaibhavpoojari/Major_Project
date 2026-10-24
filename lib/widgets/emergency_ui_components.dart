import 'package:flutter/material.dart';
import '../services/sensor_service.dart';

enum BadgeStatusType {
  active,
  warning,
  critical,
  info,
  neutral,
}

/// Smooth staggered fade + slide entrance transition for widgets
class FadeSlideTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay = Duration.zero,
    this.offset = const Offset(0.0, 0.06),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Interactive pressable wrapper with subtle scale feedback, ripple, and elevation
class InteractivePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;

  const InteractivePressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.pressedScale = 0.97,
  });

  @override
  State<InteractivePressable> createState() => _InteractivePressableState();
}

class _InteractivePressableState extends State<InteractivePressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Status Pill Badge with colored glowing dot and clean border
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatusType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeStatusType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case BadgeStatusType.active:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF34D399);
        border = const Color(0xFF10B981).withValues(alpha: 0.4);
        break;
      case BadgeStatusType.warning:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFFBBF24);
        border = const Color(0xFFF59E0B).withValues(alpha: 0.4);
        break;
      case BadgeStatusType.critical:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.16);
        fg = const Color(0xFFF87171);
        border = const Color(0xFFEF4444).withValues(alpha: 0.45);
        break;
      case BadgeStatusType.info:
        bg = const Color(0xFF0EA5E9).withValues(alpha: 0.15);
        fg = const Color(0xFF38BDF8);
        border = const Color(0xFF0EA5E9).withValues(alpha: 0.4);
        break;
      case BadgeStatusType.neutral:
        bg = const Color(0xFF64748B).withValues(alpha: 0.14);
        fg = const Color(0xFF94A3B8);
        border = const Color(0xFF64748B).withValues(alpha: 0.3);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fg.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Continuous glowing radar halo pulse for live telemetry and emergencies
class EmergencyPulseIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const EmergencyPulseIndicator({
    super.key,
    this.size = 18,
    this.color = const Color(0xFF10B981),
  });

  @override
  State<EmergencyPulseIndicator> createState() => _EmergencyPulseIndicatorState();
}

class _EmergencyPulseIndicatorState extends State<EmergencyPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25 * _animation.value),
                ),
              ),
              Container(
                width: widget.size * 0.55,
                height: widget.size * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.7 * _animation.value),
                      blurRadius: 8 * _animation.value,
                      spreadRadius: 1.5 * _animation.value,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Clean Section Header with Outfit Typography and Subtitle
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Professional Emergency Hospital Card with Rank Badge and Call Action
class EmergencyHospitalCard extends StatelessWidget {
  final int rank;
  final String name;
  final double? distanceKm;
  final String facilityType;
  final String emergencyCapability;
  final String ownership;
  final String? address;
  final String? phone;
  final VoidCallback? onCall;

  const EmergencyHospitalCard({
    super.key,
    required this.rank,
    required this.name,
    this.distanceKm,
    required this.facilityType,
    required this.emergencyCapability,
    required this.ownership,
    this.address,
    this.phone,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmergencyReady = emergencyCapability == 'Yes';
    final bool hasPhone = phone != null && phone!.trim().isNotEmpty;
    final String distStr = distanceKm != null ? "${distanceKm!.toStringAsFixed(2)} km" : "Distance N/A";

    return FadeSlideTransition(
      delay: Duration(milliseconds: rank * 50),
      duration: const Duration(milliseconds: 280),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmergencyReady ? const Color(0xFFE11D48).withValues(alpha: 0.45) : const Color(0xFF26334D),
            width: isEmergencyReady ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isEmergencyReady
                  ? const Color(0xFFE11D48).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEmergencyReady
                            ? [const Color(0xFFE11D48).withValues(alpha: 0.3), const Color(0xFFBE123C).withValues(alpha: 0.15)]
                            : [const Color(0xFF0EA5E9).withValues(alpha: 0.25), const Color(0xFF0284C7).withValues(alpha: 0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isEmergencyReady
                            ? const Color(0xFFE11D48).withValues(alpha: 0.5)
                            : const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "#$rank",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isEmergencyReady ? const Color(0xFFFB7185) : const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (address != null && address!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            address!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      distStr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: facilityType,
                    type: isEmergencyReady ? BadgeStatusType.critical : BadgeStatusType.info,
                  ),
                  StatusBadge(
                    label: "Emergency: $emergencyCapability",
                    type: isEmergencyReady ? BadgeStatusType.active : BadgeStatusType.neutral,
                  ),
                  StatusBadge(
                    label: ownership,
                    type: BadgeStatusType.neutral,
                  ),
                ],
              ),
              if (hasPhone) ...[
                const Divider(height: 20, color: Color(0xFF26334D)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        Text(
                          phone!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                    if (onCall != null)
                      InteractivePressable(
                        onTap: onCall,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.call, size: 13, color: Color(0xFF34D399)),
                              SizedBox(width: 4),
                              Text(
                                "Call",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const Divider(height: 20, color: Color(0xFF26334D)),
                const Row(
                  children: [
                    Icon(Icons.phone_disabled_outlined, size: 14, color: Color(0xFF94A3B8)),
                    SizedBox(width: 6),
                    Text(
                      "Phone number unavailable in directory",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Real-time 3-Axis (X/Y/Z + Magnitude) Accelerometer Waveform Graph
class RealtimeAccelerometerGraph extends StatefulWidget {
  final List<SensorVectorReading> buffer;
  final double currentX;
  final double currentY;
  final double currentZ;
  final double currentMagnitude;
  final double threshold;

  const RealtimeAccelerometerGraph({
    super.key,
    required this.buffer,
    required this.currentX,
    required this.currentY,
    required this.currentZ,
    required this.currentMagnitude,
    this.threshold = SensorService.crashThreshold,
  });

  @override
  State<RealtimeAccelerometerGraph> createState() => _RealtimeAccelerometerGraphState();
}

class _RealtimeAccelerometerGraphState extends State<RealtimeAccelerometerGraph> {
  String _selectedChannel = 'All'; // 'All', 'X', 'Y', 'Z', 'Mag'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26334D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with channel filter chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text(
                    "REAL-TIME X/Y/Z ACCELEROMETER",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              // Channel selection dropdown or badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF26334D)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['All', 'X', 'Y', 'Z', '|a|'].map((ch) {
                    final isSel = _selectedChannel == ch;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedChannel = ch),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF38BDF8).withValues(alpha: 0.25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ch,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Metric Readout Strip
          Row(
            children: [
              _buildChannelChip("X", widget.currentX, const Color(0xFFEF4444)),
              const SizedBox(width: 6),
              _buildChannelChip("Y", widget.currentY, const Color(0xFF10B981)),
              const SizedBox(width: 6),
              _buildChannelChip("Z", widget.currentZ, const Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              _buildChannelChip("|a|", widget.currentMagnitude, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 14),

          // Custom Painted Waveform Canvas
          SizedBox(
            height: 150,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _AccelerometerWaveformPainter(
                  readings: widget.buffer,
                  currentX: widget.currentX,
                  currentY: widget.currentY,
                  currentZ: widget.currentZ,
                  currentMagnitude: widget.currentMagnitude,
                  threshold: widget.threshold,
                  channelFilter: _selectedChannel,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Subtext Legend & Scale Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 2, color: const Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  const Text("X: Lat", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 2, color: const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  const Text("Y: Long", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 2, color: const Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  const Text("Z: Norm", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 2, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  const Text("|a|", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Text(
                "Trigger: ≥${widget.threshold.toInt()} m/s²",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFB7185),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              val.toStringAsFixed(1),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccelerometerWaveformPainter extends CustomPainter {
  final List<SensorVectorReading> readings;
  final double currentX;
  final double currentY;
  final double currentZ;
  final double currentMagnitude;
  final double threshold;
  final String channelFilter;

  _AccelerometerWaveformPainter({
    required this.readings,
    required this.currentX,
    required this.currentY,
    required this.currentZ,
    required this.currentMagnitude,
    required this.threshold,
    required this.channelFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Grid & Framing
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final double midY = size.height / 2;
    const double maxRange = 50.0; // +/- 50 m/s^2 full scale

    double valueToY(double val) {
      final clamped = val.clamp(-maxRange, maxRange);
      return midY - (clamped / maxRange) * (size.height / 2 - 8);
    }

    // Grid baseline lines (0, +/-25, +/-35 m/s^2)
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    // Baseline 0 m/s^2
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);

    // Grid +/- 20 m/s^2
    canvas.drawLine(Offset(0, valueToY(20)), Offset(size.width, valueToY(20)), gridPaint);
    canvas.drawLine(Offset(0, valueToY(-20)), Offset(size.width, valueToY(-20)), gridPaint);

    // Alarm Threshold +/- 35 m/s^2 dashed red line
    final threshPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final double threshYPos = valueToY(threshold);
    final double threshYNeg = valueToY(-threshold);

    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, threshYPos), Offset(x + 5, threshYPos), threshPaint);
      canvas.drawLine(Offset(x, threshYNeg), Offset(x + 5, threshYNeg), threshPaint);
    }

    if (readings.isEmpty) return;

    // Draw lines for active channels
    void drawChannelLine(List<double> values, Color color, double strokeW) {
      if (values.length < 2) return;
      final path = Path();
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final double stepX = size.width / (values.length - 1);

      for (int i = 0; i < values.length; i++) {
        final double x = i * stepX;
        final double y = valueToY(values[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);

      // Latest point dot indicator
      final latestX = (values.length - 1) * stepX;
      final latestY = valueToY(values.last);
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(latestX, latestY), 3.0, dotPaint);
    }

    final xVals = readings.map((r) => r.x).toList();
    final yVals = readings.map((r) => r.y).toList();
    final zVals = readings.map((r) => r.z).toList();
    final magVals = readings.map((r) => r.magnitude).toList();

    if (channelFilter == 'All' || channelFilter == 'X') {
      drawChannelLine(xVals, const Color(0xFFEF4444), 1.6);
    }
    if (channelFilter == 'All' || channelFilter == 'Y') {
      drawChannelLine(yVals, const Color(0xFF10B981), 1.6);
    }
    if (channelFilter == 'All' || channelFilter == 'Z') {
      drawChannelLine(zVals, const Color(0xFF38BDF8), 1.6);
    }
    if (channelFilter == 'All' || channelFilter == '|a|') {
      drawChannelLine(magVals, const Color(0xFFF59E0B), 2.2);
    }
  }

  @override
  bool shouldRepaint(covariant _AccelerometerWaveformPainter oldDelegate) => true;
}

/// Concise, factual comparison dialog: Accident Guard vs. Phone Built-In Crash Detection vs. India 112
class EmergencySystemComparisonDialog extends StatelessWidget {
  const EmergencySystemComparisonDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFF26334D)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: const Row(
        children: [
          Icon(Icons.compare_arrows_rounded, color: Color(0xFF38BDF8), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Emergency Systems Comparison",
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Concise factual evaluation across built-in crash detection, national 112, and Accident Guard:",
                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),

              _buildComparisonCard(
                title: "1. Built-in Phone Crash Detection (Apple / Pixel)",
                badge: "OS-Level Co-Processor",
                badgeType: BadgeStatusType.info,
                points: [
                  "Sensor Fusion: Proprietary algorithms combining high-g accelerometer (up to 256 Gs), HDR gyroscope, barometer (airbag cabin pressure changes), and microphone.",
                  "Screen-Off State: Supported 24/7 at low power via dedicated OS-privileged sensor co-processor.",
                  "Notification Targets: Calls local emergency answering services (911/112) with automated audio and notifies Apple/Google Medical ID contacts.",
                  "Limitations: Tied to expensive specific smartphone models (iPhone 14+, Pixel 3+). Does not geocode nearest hospitals via OpenStreetMap or dispatch custom medical SMS gateways.",
                ],
              ),
              const SizedBox(height: 12),

              _buildComparisonCard(
                title: "2. India's 112 Emergency System (ERSS)",
                badge: "National Public Safety (CAD)",
                badgeType: BadgeStatusType.warning,
                points: [
                  "Mechanism: Unified national helpline across India integrating Police (100), Fire (101), and Ambulance (108).",
                  "Collision Detection: None on smartphone. Relies on manual telephone call, SMS, or external vehicle-installed AIS-140 GPS panic buttons.",
                  "Dispatch Routing: Central Emergency Response Centre dispatches the nearest physical government PCR patrol van or 108 ambulance.",
                  "Limitations: Requires conscious human voice interaction or dedicated vehicle telematics hardware; no automatic smartphone accelerometer detection.",
                ],
              ),
              const SizedBox(height: 12),

              _buildComparisonCard(
                title: "3. Accident Guard System",
                badge: "Open Flutter Platform",
                badgeType: BadgeStatusType.active,
                points: [
                  "Detection: Real-time 3-axis accelerometer vector telemetry (|a| ≥ 35.0 m/s²) with X/Y/Z directional decomposition.",
                  "Autonomous Dispatches: Direct Native SIM SMS, TextBee SMS Gateway, and SMTP Email with GPS link and driver blood group sent directly to personal guardians.",
                  "Hospital Discovery: Queries OpenStreetMap live to geocode top 3 nearest trauma facilities with driving distances.",
                  "Screen-Off Limitation: Requires phone screen active / app in foreground due to standard Android OS background sensor throttling policies.",
                  "Accessibility: Free, device-agnostic, and works on any standard Android smartphone.",
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        InteractivePressable(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Text(
              "Close",
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildComparisonCard({
    required String title,
    required String badge,
    required BadgeStatusType badgeType,
    required List<String> points,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26334D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              StatusBadge(label: badge, type: badgeType),
            ],
          ),
          const SizedBox(height: 10),
          ...points.map(
            (pt) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      pt,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFCBD5E1), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

