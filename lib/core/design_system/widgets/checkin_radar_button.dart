import 'dart:io';
import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

class CheckInRadarButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool disabled;
  final bool loading;
  final bool isCheckOut;
  final VoidCallback onTap;

  const CheckInRadarButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.disabled,
    required this.loading,
    this.isCheckOut = false,
    required this.onTap,
  });

  @override
  State<CheckInRadarButton> createState() => _CheckInRadarButtonState();
}

class _CheckInRadarButtonState extends State<CheckInRadarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // In unit/widget/integration tests, repeating animations cause pumpAndSettle to time out
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isCheckOut ? AppTheme.errorColor : AppTheme.primaryColor;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer radar glowing ring
          if (!widget.disabled)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Intermediate ring
          if (!widget.disabled)
            Container(
              width: 174,
              height: 174,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
            ),

          // Main Button
          GestureDetector(
            onTap: widget.disabled || widget.loading ? null : widget.onTap,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
                gradient: widget.disabled
                    ? const LinearGradient(
                        colors: [AppTheme.surface03, AppTheme.surface02],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : widget.isCheckOut
                        ? AppTheme.dangerGradient
                        : AppTheme.primaryGradient,
                boxShadow: widget.disabled
                    ? []
                    : [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.28),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: widget.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.icon, size: 44, color: Colors.white),
                            const SizedBox(height: 6),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
