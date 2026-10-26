import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

/// Base building block for skeleton placeholders with a smooth pulse animation.
class SkeletonBone extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const SkeletonBone({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.shape,
  });

  const SkeletonBone.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = const CircleBorder();

  @override
  State<SkeletonBone> createState() => _SkeletonBoneState();
}

class _SkeletonBoneState extends State<SkeletonBone>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.85).animate(
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
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: widget.shape != null
            ? ShapeDecoration(
                color: AppTheme.surface03,
                shape: widget.shape!,
              )
            : BoxDecoration(
                color: AppTheme.surface03,
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
      ),
    );
  }
}

/// Layout-matched skeleton for the Home / Dashboard screen.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header placeholder
          Row(
            children: [
              const SkeletonBone.circular(size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBone(width: 140, height: 18),
                    SizedBox(height: 8),
                    SkeletonBone(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attendance teaser card placeholder
          WolfCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SkeletonBone.circular(size: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBone(width: 120, height: 16),
                      SizedBox(height: 8),
                      SkeletonBone(width: 180, height: 12),
                    ],
                  ),
                ),
                const SkeletonBone(width: 60, height: 28, borderRadius: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Priority strip placeholder
          Row(
            children: [
              Expanded(
                child: WolfCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    children: const [
                      SkeletonBone.circular(size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: SkeletonBone(height: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WolfCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    children: const [
                      SkeletonBone.circular(size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: SkeletonBone(height: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick actions grid placeholder
          const SkeletonBone(width: 100, height: 16),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: List.generate(
              4,
              (index) => WolfCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonBone.circular(size: 32),
                    SizedBox(height: 10),
                    SkeletonBone(width: 80, height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout-matched skeleton for Requests list (Employee history & General catalog).
class RequestListSkeleton extends StatelessWidget {
  final int itemCount;

  const RequestListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return WolfCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBone(width: 130, height: 16),
                  SkeletonBone(width: 70, height: 22, borderRadius: 11),
                ],
              ),
              const SizedBox(height: 12),
              const SkeletonBone(width: 220, height: 12),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBone(width: 90, height: 12),
                  SkeletonBone(width: 110, height: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Layout-matched skeleton for Reviewer Inbox cards.
class InboxSkeleton extends StatelessWidget {
  final int itemCount;

  const InboxSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return WolfCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonBone.circular(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBone(width: 120, height: 16),
                        SizedBox(height: 6),
                        SkeletonBone(width: 80, height: 12),
                      ],
                    ),
                  ),
                  const SkeletonBone(width: 60, height: 20, borderRadius: 10),
                ],
              ),
              const SizedBox(height: 14),
              const SkeletonBone(width: double.infinity, height: 14),
              const SizedBox(height: 8),
              const SkeletonBone(width: 180, height: 12),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: SkeletonBone(height: 38, borderRadius: 8),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBone(height: 38, borderRadius: 8),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Layout-matched skeleton for Request Detail screens.
class DetailScreenSkeleton extends StatelessWidget {
  const DetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary card
          WolfCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBone(width: 140, height: 20),
                    SkeletonBone(width: 80, height: 24, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 16),
                const SkeletonBone(width: 100, height: 12),
                const SizedBox(height: 8),
                const SkeletonBone(width: 180, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fields card
          WolfCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                4,
                (i) => Padding(
                  padding: EdgeInsets.only(bottom: i < 3 ? 16.0 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBone(width: 90, height: 14),
                      SkeletonBone(width: 140, height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Timeline / workflow placeholder
          WolfCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBone(width: 110, height: 16),
                SizedBox(height: 16),
                SkeletonBone(
                    width: double.infinity, height: 40, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout-matched placeholder for the attendance workspace.
class AttendanceSkeleton extends StatelessWidget {
  const AttendanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WolfCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBone(width: 120, height: 16),
                SizedBox(height: 12),
                SkeletonBone(width: 200, height: 24),
                SizedBox(height: 8),
                SkeletonBone(width: 150, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: SkeletonBone.circular(size: 176)),
          const SizedBox(height: 18),
          const SkeletonBone(height: 52, borderRadius: 14),
          const SizedBox(height: 20),
          WolfCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBone(width: 110, height: 16),
                SizedBox(height: 14),
                SkeletonBone(height: 14),
                SizedBox(height: 10),
                SkeletonBone(width: 220, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout-matched placeholder for the notification center.
class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => WolfCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBone.circular(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBone(width: 150, height: 16),
                  SizedBox(height: 8),
                  SkeletonBone(height: 13),
                  SizedBox(height: 7),
                  SkeletonBone(width: 92, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout-matched placeholder for the profile header and account settings.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          WolfCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SkeletonBone.circular(size: 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBone(width: 160, height: 20),
                      SizedBox(height: 8),
                      SkeletonBone(width: 190, height: 13),
                      SizedBox(height: 8),
                      SkeletonBone(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WolfCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: List.generate(
                5,
                (index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SkeletonBone.circular(size: 24),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBone(height: 14)),
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
