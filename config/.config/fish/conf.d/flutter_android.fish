# Flutter / Android SDK
set -gx FLUTTER_HOME /opt/flutter
set -gx ANDROID_HOME /opt/android-sdk
set -gx ANDROID_SDK_ROOT /opt/android-sdk
set -gx JAVA_HOME /usr/lib/jvm/java-26-openjdk
set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable
fish_add_path -g /opt/flutter/bin /opt/android-sdk/cmdline-tools/latest/bin /opt/android-sdk/platform-tools /opt/android-sdk/emulator
