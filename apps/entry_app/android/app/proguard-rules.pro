# WorkManager + AGP 9 / R8 full mode
# Prevents release crash: Failed to create an instance of androidx.work.impl.WorkDatabase
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.impl.**
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
