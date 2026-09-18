# ── WorkManager ───────────────────────────────────────────────────────────────
# WorkManager uses Room internally. R8 must not remove the Room-generated
# WorkDatabase_Impl class or any of its constructors.
# Without these rules, release builds crash with:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl. []
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ── App Startup ───────────────────────────────────────────────────────────────
-keep class androidx.startup.** { *; }
-keep class * extends androidx.startup.Initializer { *; }
-dontwarn androidx.startup.**

# ── EncryptedSharedPreferences / Tink ────────────────────────────────────────
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class androidx.security.crypto.** { *; }

# ── Flutter embedding ─────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── App Kotlin classes (native bridge) ───────────────────────────────────────
-keep class com.findmyphone.find_my_phone.** { *; }
