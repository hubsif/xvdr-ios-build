#!/bin/bash

# based on script from http://stackoverflow.com/questions/27016612/compiling-external-c-library-for-use-with-ios-project

PLATFORMPATH="/Applications/Xcode.app/Contents/Developer/Platforms"
TOOLSPATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
export IPHONEOS_DEPLOYMENT_TARGET="8.1"
pwd=`pwd`

findLatestSDKVersion()
{
    sdks=`ls $PLATFORMPATH/$1.platform/Developer/SDKs`
    arr=()
    for sdk in $sdks
    do
       arr[${#arr[@]}]=$sdk
    done

    # Last item will be the current SDK, since it is alpha ordered
    count=${#arr[@]}
    if [ $count -gt 0 ]; then
       sdk=${arr[$count-1]:${#1}}
       num=`expr ${#sdk}-4`
       SDKVERSION=${sdk:0:$num}
    else
       echo "No SDK found! Exiting..."
       exit 1
    fi
}

buildit()
{
    target=$1
    hosttarget=$1
    platform=$2

    if [[ $hosttarget == "x86_64" ]]; then
        hostarget="i386"
    elif [[ $hosttarget == "arm64" ]]; then
        hosttarget="arm"
    fi

    export CC="$(xcrun -sdk iphoneos -find clang)"
    export CPP="$CC -E"
    export CFLAGS="-arch ${target} -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk -miphoneos-version-min=$SDKVERSION"
    export AR=$(xcrun -sdk iphoneos -find ar)
    export RANLIB=$(xcrun -sdk iphoneos -find ranlib)
    export CPPFLAGS="-arch ${target}  -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk -miphoneos-version-min=$SDKVERSION"
    export LDFLAGS="-arch ${target} -isysroot $PLATFORMPATH/$platform.platform/Developer/SDKs/$platform$SDKVERSION.sdk"

    mkdir -p $pwd/output/$target

     ./configure --prefix="$pwd/output/$target" --host=$hosttarget-apple-darwin

    make clean
    make
    make install
}

if [ ! -f configure ]; then
  echo "\"configure\" not found. Please run autogen.sh first!"
  exit 1
fi

findLatestSDKVersion iPhoneOS

buildit armv7 iPhoneOS
buildit armv7s iPhoneOS
buildit arm64 iPhoneOS
#buildit i386 iPhoneSimulator
#buildit x86_64 iPhoneSimulator
#
#LIPO=$(xcrun -sdk iphoneos -find lipo)
#$LIPO -create $pwd/output/armv7/lib/libpresage.a  $pwd/output/armv7s/lib/libpresage.a $pwd/output/arm64/lib/libpresage.a $pwd/output/x86_64/lib/libpresage.a $pwd/output/i386/lib/libpresage.a -output libpresage.a

# install addon files to output/package
make install prefix="$pwd/output/package"

# package platform libraries (and overwrite last installed)
shopt -s extglob
LIPO=$(xcrun -sdk iphoneos -find lipo)
$LIPO -create $pwd/output/!(package*)/addons/pvr.vdr.xvdr/XBMC_VDR_xvdr_OSX.pvr -output "$pwd/output/package/addons/pvr.vdr.xvdr/XBMC_VDR_xvdr_OSX.pvr"

# patch addon.xml
cd "$pwd/output/package/addons/pvr.vdr.xvdr"
patch <<'EOF'
--- addon.xml.orig	2014-12-04 18:54:28.000000000 +0100
+++ addon.xml	2014-12-04 18:54:33.000000000 +0100
@@ -2,23 +2,19 @@
 <addon
   id="pvr.vdr.xvdr"
   version="0.9.8"
-  name="VDR XVDR Client"
+  name="VDR XVDR Client for iOS"
   provider-name="Alexander Pipelka, Alwin Esch, Team XBMC">
   <requires>
     <c-pluff version="0.1"/>
   </requires>
   <extension
     point="xbmc.pvrclient"
-    library_osx="XBMC_VDR_xvdr_OSX.pvr"
-    library_linux="XBMC_VDR_xvdr.pvr"
-    library_wingl="XBMC_VDR_xvdr_WIN32.pvr"
-    library_windx="XBMC_VDR_xvdr_WIN32.pvr"
-    library_android="libXBMC_VDR_xvdr.so"/>
+    library_osx="XBMC_VDR_xvdr_OSX.pvr"/>
   <extension point="xbmc.addon.metadata">
     <summary>PVR client to connect VDR to XBMC</summary>
     <description>VDR frontend; supporting streaming of Live TV &amp; Recordings, EPG, Timers</description>
     <description lang="de">Erlaubt das wiedergeben von Live TV und Aufnahmen mittels VDR auf XBMC. Des weiteren werden EPG, Kanalsuche und Timer unterstützt.</description>
     <disclaimer>This is unstable software! The authors are in no way responsible for failed recordings, incorrect timers, wasted hours, or any other undesirable effects..</disclaimer>
-    <platform>linux windx wingl osx android</platform>
+    <platform>ios</platform>
   </extension>
 </addon>
EOF

# create addon zipfile
cd "$pwd/output/package/addons/"
zip -r pvr.vdr.xvdr.zip pvr.vdr.xvdr

echo
echo " === FINISHED ==="
echo "(Hopefully) Created addon zipfile in $pwd/output/package/addons/pvr.vdr.xvdr.zip"
echo


