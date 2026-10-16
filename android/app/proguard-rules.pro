# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep MainActivity and application classes
-keep class com.bodega.bodega_mobile.** { *; }

# Shorebird Code Push updater
-keep class dev.shorebird.** { *; }
-dontwarn dev.shorebird.**

# ML Kit (Mobile Scanner) & Google Play Services
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Play Core & Split Install (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**

# Flutter Secure Storage (Android Keystore / EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Local Auth & AndroidX Biometrics
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn io.flutter.plugins.localauth.**
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

