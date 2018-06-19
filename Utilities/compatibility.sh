#!/bin/sh

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Discord and we'll help you get setup."
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
        if [[ $XCBVERSION == *"Xcode 8"* ]];
        then
            echo "✅  Xcode 8 is compatible with Vapor 2."
            echo "❌  Xcode 9 or later is required for Vapor 3."
        elif [[ $XCBVERSION == *"Xcode 9"* ]];
        then
            echo "✅  Xcode 9 is compatible with Vapor 2."
            echo "✅  Xcode 9 is compatible with Vapor 3."
        elif [[ $XCBVERSION == *"Xcode 10"* ]];
        then
            echo "⚠️  Xcode 10 support hasn't been tested yet."
            echo "ℹ️  Xcode 10 should be compatible with Vapor 2."
            echo "ℹ️  Xcode 10 should be compatible with Vapor 3."
            echo ""
        else
            echo "⚠️  We don't recognize your Command Line Tools version."
            echo ""
            echo "Open Xcode and make sure the correct SDK is selected:"
            echo "👀  Xcode > Preferences > Locations > Command Line Tools"
            echo ""
            echo "Expected: Xcode 8 or 9 (Any Build Number)"
            echo "Current: $XCBVERSION"
            echo ""
            help
            return 1;
        fi
    fi

    SWIFTV=`swift --version`

    if [[ $SWIFTV == *"Swift version 3.1"* ]];
    then
        echo "✅  Swift 3.1 is compatible with Vapor 2."
        echo "❌  Swift 4.1 or later is required for Vapor 3."
        return 0;
    elif [[ $SWIFTV == *"Swift version 4.0"* ]];
    then
        echo "✅  Swift 4.0 is compatible with Vapor 2."
        echo "❌  Swift 4.1 or later is required for Vapor 3."
        return 0;
    elif [[ $SWIFTV == *"Swift version 4.1"* ]];
    then
        echo "✅  Swift 4.1 is compatible with Vapor 2."
        echo "✅  Swift 4.1 is compatible with Vapor 3."
        return 0;
    elif [[ $SWIFTV == *"Swift version 4.2"* ]];
    then
        echo "⚠️  Swift 4.2 support hasn't been tested yet."
        echo "ℹ️  Swift 4.2 should be compatible with Vapor 2."
        echo "ℹ️  Swift 4.2 should be compatible with Vapor 3."
        echo ""
        return 0;
    elif [[ $SWIFTV == *"Swift version 5."* ]];
    then
        echo "⚠️  Swift 5 support matrix hasn't been determined yet. Reach out to the developers on GitHub or Slack."
        echo ""
        help
        return 1;
    else    
        echo "❌  Swift 3.1 or later is required for Vapor 2."
        echo "❌  Swift 4.1 or later is required for Vapor 3."
        echo ""
        echo "'swift --version' output:"
        echo $SWIFTV
        echo ""
        echo "Output does not contain any of the expected versions."
        echo "It's possible your version (especially newer Swift) may still work."
        echo ""
        help
        return 1;
    fi
}

check_vapor;
