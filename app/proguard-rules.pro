# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /tools/android/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# If you use reflection or JNI commands, consider using the following rules:
#-keepattributes Signature
#-keepattributes *Annotation*
#-keep class com.mycompany.myclasses.** { *; }
#-keep interface com.mycompany.myclasses.** { *; }
#-keepclassmembers class * {
#    @android.webkit.JavascriptInterface <methods>;
#}
