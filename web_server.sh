#!/bin/bash
export JAVA_HOME=$HOME/tools/jdk
export PATH=$JAVA_HOME/bin:$HOME/flutter/bin:$PATH
export ANDROID_HOME=$HOME/android-sdk
export ANDROID_SDK_ROOT=$HOME/android-sdk
cd /mnt/d/study/projects/Persistence-App
echo "=== starting web dev server on port 8080 ==="
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 > /tmp/webserver.log 2>&1
echo "WEB_EXIT=$?"
