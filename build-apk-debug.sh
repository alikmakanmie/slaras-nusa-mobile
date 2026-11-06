#!/usr/bin/env bash
# Build APK debug offline (VM Hatch: repo Maven lokal + IPv4 JVM).
# Pemakaian: ./build-apk-debug.sh [debug|release]
set -e
MODE="${1:-debug}"
export PATH=~/workspace/tools/flutter/bin:$PATH
export JAVA_HOME=~/workspace/tools/jdk-21
export ANDROID_SDK_ROOT=~/workspace/tools/android-sdk
export GRADLE_USER_HOME=~/workspace/tools/gradle-home
export GRADLE_OPTS="-Djava.net.preferIPv4Stack=true"
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true"
export LOCAL_MAVEN_REPO=~/workspace/tools/gradle-offline/maven-repo
cd ~/workspace/ecommerce-mobile
flutter build apk --"$MODE" --dart-define API_BASE_URL=https://api.alikmakanmie.my.id/api/v1
