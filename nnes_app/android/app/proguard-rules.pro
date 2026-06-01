# Keep classes for google_mlkit_text_recognition
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keepclassmembers class com.google.mlkit.vision.text.** { *; }
-keepclassmembers class com.google.mlkit.vision.common.** { *; }

# Keep all MLKit classes
-keep class com.google.android.gms.** { *; }
-keepclassmembers class com.google.android.gms.** { *; }

# Keep tflite classes
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
