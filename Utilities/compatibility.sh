#!/bin/sh

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
}

function check_vapor() {
    SWIFTC=`which swift`;

    if [[ $SWIFTC == "" ]];
    then
        echo "❌  Cannot find Swift."
        echo ""
        echo "ℹ️  'which swift' is empty."
        echo ""
        help
        return 1;
    fi

    OS=`uname`
    if [[ $OS == "Darwin" ]]; # macOS
    then
        XCBVERSION=`xcodebuild -version`
        if [[ $XCBVERSION != *"Xcode 9.3"* ]];
        then
            echo "⚠️  It looks like your Command Line Tools version is incorrect."
            echo ""
            echo "Open Xcode and make sure the correct SDK is selected:"
            echo "👀  Xcode > Preferences > Locations > Command Line Tools"
            echo ""
            echo "Correct: Xcode 9.3 (Any Build Number)"
            echo "Current: $XCBVERSION"
            echo ""
            help
            return 1;
        fi
    fi

    SWIFTV=`swift --version`

    if [[ $SWIFTV == *"4.1"* ]];
    then
        echo "✅  Compatible with Vapor 3"
        return 0;
    else    
        echo "❌  Swift 4.1 is required."
        echo ""
        echo "'swift --version' output:"
        echo $SWIFTV
        echo ""
        echo "Output does not contain '4.1'."
        echo ""
        help
        return 1;
    fi
}

check_vapor;
