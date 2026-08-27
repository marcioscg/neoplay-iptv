# Regras de R8/ProGuard do MIAU NET (release com minify + shrink, 1.0.8).
# O objetivo é encolher o APK sem quebrar Flutter, Firebase, Google Cast e o
# ExoPlayer/Media3 usados pelo video_player.

# ---- Flutter ----
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ---- Firebase (Auth, Firestore, Core) ----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# Modelos serializados por reflexão no Firestore.
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <methods>;
  @com.google.firebase.firestore.PropertyName <fields>;
}

# ---- Google Cast (flutter_chrome_cast / plugin felnanuke) ----
-keep class com.felnanuke.** { *; }
-keep class com.google.android.gms.cast.** { *; }
-dontwarn com.felnanuke.**

# ---- ExoPlayer / Media3 (video_player) ----
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# ---- Anotações que aparecem no classpath via Guava e afins ----
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.**
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**

# ---- flutter_secure_storage ----
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Mantém nomes de enums (usados por name em toJson/fromJson do app).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Anotações e assinaturas genéricas (necessárias para reflexão do Firestore).
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses
