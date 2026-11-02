# Flutter plugin registration is retained by Flutter generated rules.
-keepattributes Signature,InnerClasses,EnclosingMethod

# LibVLC JNI locates Java classes, constructors, fields and event callbacks by
# their original names. Keep the complete Java side, including libvlc.util.
# Flutter's generated plugin rules do not cover this direct Maven dependency.
-keep class org.videolan.** { *; }
