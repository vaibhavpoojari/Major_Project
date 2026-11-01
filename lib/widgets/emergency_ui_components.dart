import 'package:flutter/material.dart';

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

