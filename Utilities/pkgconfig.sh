#!/bin/sh

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
}

function check_pkgconfig() {
    OS=`uname`
    if [[ $OS != "Darwin" && $OS != "Linux" ]]; # macOS
    then
        echo "❌  This script is for macOS and Linux only."
        return 1;
    fi

    # Check to make sure Homebrew is installed
    BREW_PATH=`which brew`;
    if [[ $BREW_PATH != *"brew"* ]];
    then
        echo "❌  Homebrew not installed.";
        echo "";
        echo "🌎  Visit: https://brew.sh";
        echo "";
        echo "📦  Run to install:";
        echo "/usr/bin/ruby -e \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\"";
        echo "";
        help;
        return 1; 
    fi

    # Check to make sure Package Config is installed
    BREW_PACKAGES=`brew list`;
    if [[ $BREW_PACKAGES != *"pkg-config"* ]];
    then
        echo "❌  pkg-config not installed.";
        echo "";
        echo "📦  Run to install:";
        echo "brew install pkg-config";
        echo "";
        help;
        return 1; 
    fi

    VAPOR_PKG_CONFIG_PATH="/usr/local/share/vapor/pkgconfig";
    mkdir -p $VAPOR_PKG_CONFIG_PATH;


    if [[ $OS == "Darwin" ]];
    then
        DEFAULT_PROFILE_FILE=".bash_profile"
    else
        DEFAULT_PROFILE_FILE=".bashrc"
    fi

    DEFAULT_PROFILE="$HOME/$DEFAULT_PROFILE_FILE"

    read -p "Where is your bash profile? (default: $DEFAULT_PROFILE) [enter] " CHOSEN_PROFILE

    if [[ $CHOSEN_PROFILE != "" ]];
    then
        PROFILE=$CHOSEN_PROFILE
    else 
        PROFILE=$DEFAULT_PROFILE
    fi

    echo "Using bash profile: $PROFILE"

    PKG_CONFIG_EXPORT="export PKG_CONFIG_PATH=$VAPOR_PKG_CONFIG_PATH:\$PKG_CONFIG_PATH"

    if [[ $PKG_CONFIG_PATH != *"$VAPOR_PKG_CONFIG_PATH"* ]];
    then
        echo "";
        echo "⚠️  Vapor pkg-config path not found in environment";
        read -p "Would you like to add it to $PROFILE? [y/n] " -n 1 -r
        echo ""   # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo "";
            echo "🛠  Adding PKG_CONFIG_PATH to $PROFILE";
            echo "" >> $PROFILE;
            echo "# Vapor Package Config" >> $PROFILE;
            echo "$PKG_CONFIG_EXPORT;" >> $PROFILE;
            echo "";
            echo "✅  Package Config will be available once the terminal is restarted."
            return 1;
        else
            echo "";
            echo "🛠  Add this to your bash profile:"
            echo "$PKG_CONFIG_EXPORT;"
            echo "";
            echo "⚠️  Package Config will be available once bash profile is configured."
            return 1;
        fi
    fi

    echo "✅  Package Config available"
}

# Run
check_pkgconfig;
