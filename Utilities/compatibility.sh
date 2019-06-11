#!/bin/sh

function help() {
    echo "📖 Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋 or Join our Discord and we'll help you get setup."
    echo "http://vapor.team"
}

function check_vapor() {
    SWIFTC=`which swift`;

    if [[ $SWIFTC == "" ]];
    then
        echo "❌ Cannot find Swift."
        echo ""
        echo "ℹ️ 'which swift' is empty."
        return 1;
    fi

    OS=`uname`
    if [[ $OS == "Darwin" ]]; # macOS
    then
        XCBVERSION=`xcodebuild -version`
        if [[ $XCBVERSION == *"Xcode 9.3"* ]] || [[ $XCBVERSION == *"Xcode 10."* ]] || [[ $XCBVERSION == *"Xcode 11."* ]];
        then
            echo "✅ Xcode 9.3 or later is compatible with Vapor 3"
        else
            echo "❌ Xcode 9.3 or later is required for Vapor 3"
        fi
        if [[ $XCBVERSION == *"Xcode 11."* ]];
        then
            echo "✅ Xcode 11 or later is compatible with Vapor 4"
        else
            echo "❌ Xcode 11 or later is required for Vapor 4"
        fi
    fi

    SWIFTV=`swift --version`

    if  [[ $SWIFTV == *"Swift version 4.1"* ]] || 
        [[ $SWIFTV == *"Swift version 4.2"* ]] || 
        [[ $SWIFTV == *"Swift version 5."* ]] || 
        [[ $SWIFTV == *"Swift version 6."* ]];
    then
        echo "✅ Swift 4.1 or later is compatible with Vapor 3"
    else
        echo "❌ Swift 4.1 or later is required for Vapor 3"
    fi

    if [[ $SWIFTV == *"Swift version 5.1"* ]] || [[ $SWIFTV == *"Swift version 6."* ]];
    then
        echo "✅ Swift 5.1 or later is compatible with Vapor 4"
    else
        echo "❌ Swift 5.1 or later is required for Vapor 4"
    fi
}

check_vapor;

echo "";

help;
