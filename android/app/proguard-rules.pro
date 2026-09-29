# R8 keep rules for Wonder CV Builder.
#
# R8 shrinks and obfuscates the release build. Most of this app is Dart, which
# R8 never touches, but a handful of things live on the Java/Kotlin side and
# are reached by name: the Flutter embedding, the platform channels used by the
# plugins, and the app's own entry point. Losing any of them produces a release
# APK that installs and then crashes on launch, which is exactly the class of
# bug that only shows up after publishing.
#
# Flutter's own rules (proguard-android-optimize.txt plus the engine's
# flutter_proguard_rules.pro) are applied by the Flutter Gradle plugin; these
# are the additions.

# The application entry point and the Flutter embedding.
-keep class dev.cvpro.builder.MainActivity { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Platform channels are resolved by string name at runtime: a plugin that is
# obfuscated away fails only when its feature is used.
-keepclasseswithmembers class * {
    @io.flutter.plugin.common.PluginRegistry$Registrar <methods>;
}
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Plugins that reach into the Android framework by reflection.
#   printing      — PDF printing / share adapters
#   file_picker   — document URIs and file metadata
#   image_picker  — photo library and camera intents
#   share_plus    — share targets
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn com.github.dart_lang.jni.**

# sqlite3 (drift) is a native library loaded through JNI. Its Java side is
# small but resolved from the native code.
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# Keep annotation metadata that json_serializable code and Kotlin reflection
# would otherwise lose.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Kotlin metadata is needed by libraries that call Kotlin reflection. The app
# itself does not, but plugins may.
-keep class kotlin.Metadata { *; }

# AndroidX work manager / lifecycle classes used by plugins that are only
# referenced from XML or the manifest.
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**

# Keep the names of native method bindings.
-keepclasseswithmembernames class * {
    native <methods>;
}
