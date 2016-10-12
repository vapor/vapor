#!/bin/sh

SWIFTC=`which swift`

help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
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

OS=`uname`
if [[ $OS == "Darwin" ]]; # macOS
then
    XCBVERSION=`xcodebuild -version`
    if [[ $XCBVERSION != *"Xcode 8"* ]];
    then
        echo "⚠️  It looks like your Command Line Tools version is incorrect."
        echo ""
        echo "Open Xcode and make sure the correct SDK is selected:"
        echo "👀  Xcode > Preferences > Locations > Command Line Tools"
        echo ""
        echo "Correct: Xcode 8.x (Any Build Number)"
        echo "Current: $XCBVERSION"
        echo ""
        help
        exit 1;
    fi
fi

SWIFTV=`swift --version`

if [[ $SWIFTV == *"3.0"* ]];
then
    echo "✅  Compatible"
    exit 0;
else    
    echo "❌  Incompatible"
    echo "Reason: Swift 3.0 is required."
    echo ""
    echo "'swift --version' output:"
    echo $SWIFTV
    echo ""
    echo "Output does not contain '3.0'."
    echo ""
    help
    exit 1;
fi

