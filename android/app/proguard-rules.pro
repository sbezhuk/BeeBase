# Keep BuildConfig so flutter_config's env vars survive R8 shrinking/obfuscation
# in release builds. See plugins/flutter_config/doc/ANDROID.md.
-keep class com.example.beebase.BuildConfig { *; }
