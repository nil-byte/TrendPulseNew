import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';

class LoadingWidget extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const LoadingWidget({super.key, this.itemCount = 3, this.itemHeight = 120});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(itemCount: itemCount, itemHeight: itemHeight);
  }
}
