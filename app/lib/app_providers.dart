import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart'
    show apiClientProvider;

/// Monotonic counter that any feature can bump after mutating task data
/// (create, delete, etc.). Providers that display task lists should
/// [ref.watch] this so they rebuild automatically.
final taskMutationSignalProvider = StateProvider<int>((ref) => 0);
