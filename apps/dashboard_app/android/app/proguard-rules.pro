# WorkManager + AGP 9 / R8 full mode
# Prevents release crash: Failed to create an instance of androidx.work.impl.WorkDatabase
# (triggered by home_widget / flutter_local_notifications via androidx.startup)
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.impl.**
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
