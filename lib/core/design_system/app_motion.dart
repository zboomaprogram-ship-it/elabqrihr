import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum AppMotionAsset {
  splashOnboarding('assets/animations/splash_onboarding.json'),
  checkinSuccess('assets/animations/checkin_success.json'),
  requestSubmitted('assets/animations/request_submitted.json'),
  emptyRequests('assets/animations/empty_requests.json'),
  offlineSync('assets/animations/offline_sync.json'),
  noApprovals('assets/animations/no_approvals.json');

  final String path;
  const AppMotionAsset(this.path);
}

class AppMotion extends StatefulWidget {
  final AppMotionAsset asset;
  final String? assetPath;
  final String semanticLabel;
  final bool repeat;
  final double size;
  final IconData fallbackIcon;

  const AppMotion({
    super.key,
    required this.asset,
    this.assetPath,
    required this.semanticLabel,
    this.repeat = false,
    this.size = 120,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  State<AppMotion> createState() => _AppMotionState();
}

class _AppMotionState extends State<AppMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduceMotion = (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);

    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: Lottie.asset(
          widget.assetPath ?? widget.asset.path,
          controller: _controller,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            widget.fallbackIcon,
            size: widget.size * 0.55,
            color: const Color(0xFF0272F2),
          ),
          onLoaded: (composition) {
            _controller.duration = composition.duration;
            if (reduceMotion) {
              _controller.value = 1;
            } else if (widget.repeat) {
              _controller.repeat();
            } else {
              _controller.forward(from: 0);
            }
          },
        ),
      ),
    );
  }
}
