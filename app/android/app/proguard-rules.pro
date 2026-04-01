# Flutter / Play Core — keep rules minimal when R8 is enabled.
# Expand here if release builds break after enabling shrinking.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core is referenced by Flutter embedding for optional deferred components /
# split installs; it is not bundled unless you add the dependency. R8 otherwise
# fails minifyRelease (see missing_rules.txt).
-dontwarn com.google.android.play.core.**
