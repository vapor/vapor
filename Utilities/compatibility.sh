#!/bin/sh

SWIFTC=`which swift`

VALID_MAC="swiftlang-800.0.33.1"
VALID_LINUX="swift-3.0-PREVIEW-2"
VALID_XCB="8S162m"

help() {
	echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
	echo "http://docs.qutheory.io"
	echo ""
	echo "👋  or Join our Slack and we'll help you get setup."
	echo "http://slack.qutheory.io"
}

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
	XCBVERSION=`xcodebuild -version`
	if [[ $XCBVERSION != *$VALID_XCB* ]];
	then
		echo "⚠️  It looks like your Command Line Tools version is incorrect."
		echo "Make sure Xcode > Preferences > Locations > Command Line Tools is set correctly."
		echo "Correct: Xcode 8.0 ($VALID_XCB)"
		echo "Current: $XCBVERSION"
		echo ""
	fi

	SWIFTLOC=`which swift`
	SWIFTDESIRED="/usr/bin/swift" 
	if [[ $SWIFTLOC != $SWIFTDESIRED ]];
	then
		echo "⚠️  It looks like your Swift install location has been modified."
		echo "Correct: $SWIFTDESIRED"
		echo "Current: $SWIFTLOC"
		echo ""
	fi

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
		echo "Current 'swift -version' output:"
		echo $SWIFTV
		echo ""
		help
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
		echo ""
		help
		exit 1;
	fi
fi


