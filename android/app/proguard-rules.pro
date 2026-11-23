# Google ML Kit text recognition: plugin mereferensikan model bahasa lain
# (Chinese, Japanese, Korean, Devanagari) yang tidak kita sertakan.
# Tanpa aturan ini build release gagal di tahap R8.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
