#!/bin/sh

SWIFTC=`which swift`

VALID="Swift 395e967875"

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
	echo "Reason: Cannot find Swift."
	echo ""
	echo "'which swift' is empty."
	echo ""
	help
	exit 1;
fi

SWIFTV=`swift -version`;

OS=`uname`

SWIFTLOC=`which swift`
SWIFTDESIRED=".swiftenv/shims/swift" 
if [[ $SWIFTLOC != *$SWIFTDESIRED* ]];
then
	echo "⚠️  It looks like you don't have Swiftenv installed."
	echo ""
	echo "Current Swift location: $SWIFTLOC"
	echo "Should contain: $SWIFTDESIRED"
	echo ""
	echo "To install: (https://swiftenv.fuller.li/en/latest/)"
	echo "    git clone https://github.com/kylef/swiftenv.git ~/.swiftenv"
	echo ""
	echo "Then add these lines to your Bash Profile:"
	echo "    export SWIFTENV_ROOT=\"\$HOME/.swiftenv\""
	echo "    export PATH=\"\$SWIFTENV_ROOT/bin:\$PATH\""
	echo "    eval \"\$(swiftenv init -)\""
	echo ""
fi

if [[ $OS == "Darwin" ]]; # macOS
then
	XCBVERSION=`xcodebuild -version`
	if [[ $XCBVERSION != *"Xcode 8.0"* ]];
	then
		echo "⚠️  It looks like your Command Line Tools version is incorrect."
		echo ""
		echo "Open Xcode and make sure the correct SDK is selected:"
		echo "👀  Xcode > Preferences > Locations > Command Line Tools"
		echo ""
		echo "Correct: Xcode 8.0 (Any Build Number)"
		echo "Current: $XCBVERSION"
		echo ""
	fi
fi

if [[ $SWIFTV == *$VALID* ]];
then
	echo "✅  Compatible"
	exit 0;
else
	echo "❌  Incompatible"
	echo "Reason: Invalid Swift version" 
	echo ""
	echo "Output must contain '$VALID'"
	echo "Current 'swift -version' output:"
	echo $SWIFTV
	echo ""
	echo "You must have Swiftenv installed with"
	echo "swift-DEVELOPMENT-SNAPSHOT-2016-07-25-a"
	echo ""
	help
	exit 1;
fi
