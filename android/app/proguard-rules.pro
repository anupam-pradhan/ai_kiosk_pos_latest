-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.impl.StaticMDCBinder

# Stripe Terminal SDK (Tap to Pay)
-keep class com.stripe.stripeterminal.** { *; }
-keep class com.stripe.stripeterminal.external.** { *; }
-keep class com.stripe.stripeterminal.taptopay.** { *; }
-dontwarn com.stripe.stripeterminal.**
-dontwarn com.stripe.stripeterminal.taptopay.**

# Google Play Services & AIDL (used internally by Stripe Terminal)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class android.os.IInterface { *; }
-keep class * extends android.os.IInterface { *; }

# Android KeyStore and Security (for TEE/StrongBox support)
-keep class android.security.keystore.** { *; }
-keep class java.security.** { *; }
-keep class javax.crypto.** { *; }
-dontwarn android.security.keystore.**

# Tink crypto library (used by Stripe for keysets)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
