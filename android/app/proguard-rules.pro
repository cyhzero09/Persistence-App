# flutter_local_notifications 用 Gson 反序列化 scheduled_notifications.xml 里的调度记录。
# R8 混淆会剥离泛型签名，导致 release 包运行时抛
# "RuntimeException: Missing type parameter"，使 cancelAll/zonedSchedule 全部失败。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**
