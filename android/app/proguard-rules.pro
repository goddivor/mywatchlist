# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep JSON serialization models
-keepattributes *Annotation*
-keepattributes Signature
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp / HTTP
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# General
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Play Core (deferred components): Flutter's embedding refers to it, the app does not ship it.
# Without these rules R8 stops on the missing classes (release build of 2026.11.3).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
