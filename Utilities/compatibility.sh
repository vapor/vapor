#!/bin/sh

SWIFTC=`which swift`
VALID_MAC="swiftlang-800.0.33.1"
VALID_LINUX="swift-3.0-PREVIEW-2"

if [[ $SWIFTC == "" ]];
then
	echo "❌  Incompatible"
	echo ""
	echo "You don't have Swift installed."
	echo "'which swift' is empty."
	exit 1;
fi

SWIFTV=`swift -version`;

OS=`uname`

if [[ $OS == "Darwin" ]]; # macOS
then
	if [[ $SWIFTV == *$VALID_MAC* ]];
	then
		echo "✅  Compatible"
		exit 0;
	else
		echo "❌  Incompatible"
		echo ""
		echo "Reason: Invalid Swift version" 
		echo "Output must contain '$VALID_MAC'"
		echo ""
		echo "Make sure Xcode > Preferences > Locations > Command Line Tools is set to:"
		echo "Xcode 8.0 (8S162m)"
		echo ""
		echo "Current 'swift -version' output:"
		echo $SWIFTV
		exit 1;
	fi
else # Linux
	if [[ $SWIFTV == *$VALID_LINUX* ]];
	then
		echo "✅  Compatible"
		exit 0;
	else
		echo "❌  Incompatible"
		echo ""
		echo "Reason: Invalid Swift version" 
		echo "Output must contain '$VALID_LINUX'"
		echo ""
		echo "Make sure you have Swift 3.0 Preview 2 installed from Swift.org."
		echo "If you have already installed, then make sure your PATH is pointing to the correct version."
		echo ""
		echo "Current 'swift -version' output:"
		echo $SWIFTV
		exit 1;
	fi
fi


