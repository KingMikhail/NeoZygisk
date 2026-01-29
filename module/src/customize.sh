# shellcheck disable=SC2034
SKIPUNZIP=1

DEBUG=@DEBUG@
MIN_APATCH_VERSION=@MIN_APATCH_VERSION@
MIN_KSU_VERSION=@MIN_KSU_VERSION@
MIN_KSUD_VERSION=@MIN_KSUD_VERSION@
MAX_KSU_VERSION=@MAX_KSU_VERSION@
MIN_MAGISK_VERSION=@MIN_MAGISK_VERSION@

if [ "$BOOTMODE" ] && [ "$APATCH" ]; then
  ui_print "- Installing from APatch app"
  if ! [ "$APATCH_VER_CODE" ] || [ "$APATCH_VER_CODE" -lt "$MIN_APATCH_VERSION" ]; then
    ui_print "*****"
    ui_print "! APatch Version Old Unsupported"
    ui_print "! Update APatch To Latest Version"
    abort    "*****"
  fi
  if [ "$(which magisk)" ]; then
    ui_print "*****"
    ui_print "! Multiple Root Implementation Not Supported!"
    ui_print "! Uninstall Magisk Before Installing NeoZygisk"
    abort    "*****"
  fi
elif [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "Installing From KernelSU App"
  ui_print "KernelSU Version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt "$MIN_KSU_VERSION" ]; then
    ui_print "*****"
    ui_print "! KernelSU Version Old"
    ui_print "! Update KernelSU To Latest Version"
    abort    "*****"
  elif [ "$KSU_KERNEL_VER_CODE" -ge "$MAX_KSU_VERSION" ]; then
    ui_print "*****"
    ui_print "! KernelSU Version Too Large"
    ui_print "! Support For KernelSU (Variant) Could Be Incomplete"
    ui_print "*****"
  fi
  if ! [ "$KSU_VER_CODE" ] || [ "$KSU_VER_CODE" -lt "$MIN_KSUD_VERSION" ]; then
    ui_print "*****"
    ui_print "! KSUD Version Too Old"
    ui_print "! Update KernelSU App To Latest Version"
    abort    "*****"
  fi
  if [ "$(which magisk)" ]; then
    ui_print "*****"
    ui_print "! Multiple Root implementation Not Supported"
    ui_print "! Uninstall Magisk Before Installing NeoZygisk"
    abort    "*****"
  fi
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "Installing From Magisk App"
  if [ "$MAGISK_VER_CODE" -lt "$MIN_MAGISK_VERSION" ]; then
    ui_print "*****"
    ui_print "! Magisk Version Too Old"
    ui_print "! Update Magisk To Latest Version"
    abort    "*****"
  fi
else
  ui_print "*****"
  ui_print "! Install From Recovery Not Supported"
  ui_print "! Install From APatch, KernelSU Or Magisk App"
  abort    "*****"
fi

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "Installing NeoZygisk $VERSION"

# check android
if [ "$API" -lt 26 ]; then
  ui_print "! Unsupported SDK: $API"
  abort "Minimal Supported SDK 26 (Android 8.0)"
else
  ui_print "Device SDK: $API"
fi

# check architecture
if [ "$ARCH" != "arm" ] && [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86" ] && [ "$ARCH" != "x64" ]; then
  abort "! Unsupported Platform: $ARCH"
else
  ui_print "Device Platform: $ARCH"
fi

ui_print "Extracting verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*****"
  ui_print "! Unable To Extract"
  ui_print "! Zip Corrupted, Try Downloading Again"
  abort    "*****"
fi
. "$TMPDIR/verify.sh"
extract "$ZIPFILE" 'customize.sh'  "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'verify.sh'     "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'sepolicy.rule' "$TMPDIR"

if [ "$KSU" ]; then
  ui_print "Checking SELinux Patches"
  if ! check_sepolicy "$TMPDIR/sepolicy.rule"; then
    ui_print "*****"
    ui_print "! Unable To Apply SELinux Patches"
    ui_print "! Kernel May Not Support SELinux Patch Fully"
    abort    "*****"
  fi
fi

ui_print "- Extracting Module Files"
extract "$ZIPFILE" 'action.sh'     "$MODPATH"
extract "$ZIPFILE" 'module.prop'     "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh' "$MODPATH"
extract "$ZIPFILE" 'service.sh'      "$MODPATH"
extract "$ZIPFILE" 'uninstall.sh'      "$MODPATH"
extract "$ZIPFILE" 'zygisk-ctl.sh'   "$MODPATH"
mv "$TMPDIR/sepolicy.rule" "$MODPATH"

mkdir "$MODPATH/bin"
mkdir "$MODPATH/lib"
mkdir "$MODPATH/lib64"
mv "$MODPATH/zygisk-ctl.sh" "$MODPATH/bin/zygisk-ctl"

if [ "$ARCH" = "x86" ]; then
  ui_print "Extracting X86 Libraries"
  extract "$ZIPFILE" 'bin/x86/zygiskd' "$MODPATH/bin" true
  mv "$MODPATH/bin/zygiskd" "$MODPATH/bin/zygiskd32"
  extract "$ZIPFILE" 'lib/x86/libzygisk.so' "$MODPATH/lib" true
  extract "$ZIPFILE" 'lib/x86/libzygisk_ptrace.so' "$MODPATH/bin" true
  mv "$MODPATH/bin/libzygisk_ptrace.so" "$MODPATH/bin/zygisk-ptrace32"
elif [ "$ARCH" = "x64" ]; then
  ui_print "Extracting X64 Libraries"
  extract "$ZIPFILE" 'bin/x86_64/zygiskd' "$MODPATH/bin" true
  mv "$MODPATH/bin/zygiskd" "$MODPATH/bin/zygiskd64"
  extract "$ZIPFILE" 'lib/x86_64/libzygisk.so' "$MODPATH/lib64" true
  extract "$ZIPFILE" 'lib/x86_64/libzygisk_ptrace.so' "$MODPATH/bin" true
  mv "$MODPATH/bin/libzygisk_ptrace.so" "$MODPATH/bin/zygisk-ptrace64"
elif [ "$ARCH" = "arm" ]; then
  ui_print "Extracting ARM Libraries"
  extract "$ZIPFILE" 'bin/armeabi-v7a/zygiskd' "$MODPATH/bin" true
  mv "$MODPATH/bin/zygiskd" "$MODPATH/bin/zygiskd32"
  extract "$ZIPFILE" 'lib/armeabi-v7a/libzygisk.so' "$MODPATH/lib" true
  extract "$ZIPFILE" 'lib/armeabi-v7a/libzygisk_ptrace.so' "$MODPATH/bin" true
  mv "$MODPATH/bin/libzygisk_ptrace.so" "$MODPATH/bin/zygisk-ptrace32"
elif [ "$ARCH" = "arm64" ]; then
  ui_print "Extracting ARM64 Libraries"
  extract "$ZIPFILE" 'bin/arm64-v8a/zygiskd' "$MODPATH/bin" true
  mv "$MODPATH/bin/zygiskd" "$MODPATH/bin/zygiskd64"
  extract "$ZIPFILE" 'lib/arm64-v8a/libzygisk.so' "$MODPATH/lib64" true
  extract "$ZIPFILE" 'lib/arm64-v8a/libzygisk_ptrace.so' "$MODPATH/bin" true
  mv "$MODPATH/bin/libzygisk_ptrace.so" "$MODPATH/bin/zygisk-ptrace64"
fi

ui_print "Setting Permissions"
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/lib" 0 0 0755 0644 u:object_r:system_lib_file:s0
set_perm_recursive "$MODPATH/lib64" 0 0 0755 0644 u:object_r:system_lib_file:s0

# If Huawei's Maple is enabled, system_server is created with a special way which is out of Zygisk's control
HUAWEI_MAPLE_ENABLED=$(grep_prop ro.maple.enable)
if [ "$HUAWEI_MAPLE_ENABLED" == "1" ]; then
  ui_print "Add Ro.maple.Enable=0"
  echo "ro.maple.enable=0" >>"$MODPATH/system.prop"
fi
