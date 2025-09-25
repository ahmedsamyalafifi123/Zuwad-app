# Keep LiveKit and WebRTC classes to prevent R8 from stripping required methods
-keep class io.livekit.** { *; }
-keep class livekit.** { *; }
-keep class org.webrtc.** { *; }

# Keep Kotlin metadata and annotations
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature, Exceptions

# Don't warn about Chromium internals used by WebRTC
-dontwarn org.chromium.**
-dontwarn com.google.protobuf.**
-dontwarn io.grpc.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Permission Handler reflection
-keep class com.baseflow.permissionhandler.** { *; }

# Keep LiveKit protocol buffers
-keep class com.google.protobuf.** { *; }
-keep class io.grpc.** { *; }

# Keep crypto classes
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Keep Room and Participant classes
-keep class io.livekit.android.room.** { *; }
-keep class io.livekit.android.room.participant.** { *; }

