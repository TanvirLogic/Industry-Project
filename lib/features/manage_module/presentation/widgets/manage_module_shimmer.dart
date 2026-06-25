import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/shimmer_widget.dart';

class ManageModuleShimmer extends StatelessWidget {
  const ManageModuleShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: ShimmerWidget(width: 200, height: 120, borderRadius: 16),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: 180, height: 20),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: 240, height: 14),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: 160, height: 14),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: double.infinity, height: 14),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: double.infinity, height: 14),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(width: 120, height: 14),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (_) => _moduleShimmer()),
        ],
      ),
    );
  }

  Widget _moduleShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerWidget(width: 140, height: 18),
          const SizedBox(height: 12),
          ShimmerWidget(width: double.infinity, height: 50, borderRadius: 12),
          const SizedBox(height: 8),
          ShimmerWidget(width: double.infinity, height: 50, borderRadius: 12),
        ],
      ),
    );
  }
}
