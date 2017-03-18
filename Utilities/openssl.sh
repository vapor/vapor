#!/bin/sh

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
}

function run() {
    OS=`uname`
    if [[ $OS != "Darwin" ]]; # macOS
    then
        echo "❌  This script is for macOS only."
        exit 1;
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
        exit 1; 
    fi

    # Check to make sure OpenSSL is installed
    BREW_PACKAGES=`brew list`;
    if [[ $BREW_PACKAGES != *"openssl"* ]];
    then
        echo "❌  OpenSSL not installed.";
        echo "";
        echo "📦  Run to install:";
        echo "brew install openssl";
        echo "";
        help;
        exit 1; 
    fi
    if [[ $BREW_PACKAGES != *"pkg-config"* ]];
    then
        echo "❌  pkg-config not installed.";
        echo "";
        echo "📦  Run to install:";
        echo "brew install pkg-config";
        echo "";
        help;
        exit 1; 
    fi

    OPENSSL_VERSION=`ls /usr/local/Cellar/openssl/`;
    OPENSSL_VERSION_DESIRED="1.0"
    if [[ $OPENSSL_VERSION != *"$OPENSSL_VERSION_DESIRED"* ]];
    then
        echo "❌  OpenSSL $OPENSSL_VERSION_DESIRED required.";
        echo ""
        echo "ℹ️  Curent version: $OPENSSL_VERSION";
        echo "";
        echo "📦  Run to update:";
        echo "brew upgrade openssl";
        echo "";
        help;
        exit 1; 
    fi

    PKG_CONFIG_PATH="/usr/local/share/vapor/pkgconfig";
    mkdir -p $PKG_CONFIG_PATH;

    OPENSSL_PKG_CONFIG="$PKG_CONFIG_PATH/openssl.pc";

    echo "prefix=/usr/local/Cellar/openssl/$OPENSSL_VERSION" > $OPENSSL_PKG_CONFIG;
    echo "exec_prefix=${prefix}" >> $OPENSSL_PKG_CONFIG;
    echo "libdir=${exec_prefix}/lib" >> $OPENSSL_PKG_CONFIG;
    echo "includedir=${prefix}/include" >> $OPENSSL_PKG_CONFIG;
    echo "Name: OpenSSL" >> $OPENSSL_PKG_CONFIG;
    echo "Description: Secure Sockets Layer and cryptography libraries and tools" >> $OPENSSL_PKG_CONFIG;
    echo "Version: $OPENSSL_VERSION" >> $OPENSSL_PKG_CONFIG;
    echo "Requires: libssl libcrypto" >> $OPENSSL_PKG_CONFIG;
    echo "Cflags: -I${includedir}" >> $OPENSSL_PKG_CONFIG;
    echo "Libs: -L${libdir} -lssl" >>  $OPENSSL_PKG_CONFIG;

    PROFILE="$HOME/.bash_profile"
    PKG_CONFIG_EXPORT="export PKG_CONFIG_PATH=/usr/local/share/vapor/pkgconfig"

    if [[ `tail $PROFILE` != *"$PKG_CONFIG_EXPORT"* ]];
    then
        echo "";
        echo "⚠️  Vapor pkg-config path not found in $PROFILE";
        read -p "Would you like to add it? [y/n] " -n 1 -r
        echo ""   # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo "";
            echo "🛠  Adding PKG_CONFIG_PATH to $PROFILE";
            echo "" >> $PROFILE;
            echo "# Vapor Package Config" >> $PROFILE;
            echo "export PKG_CONFIG_PATH=/usr/local/share/vapor/pkgconfig;" >> $PROFILE;
            echo "";
            echo "✅  OpenSSL will be available once the terminal is restarted (Run this script again to verify)"
            return;
        else
            echo "";
            echo "🛠  Add this to your bash profile:"
            echo "export PKG_CONFIG_PATH=/usr/local/share/vapor/pkgconfig;"
            echo "";
            echo "⚠️  OpenSSL will be available once bash profile is configured."
            exit 1;
        fi
    fi

    PKG_CONFIG_ALL=`pkg-config openssl --cflags`;
    if [[ $PKG_CONFIG_ALL != *"-I"* ]];
    then
        echo "";
        echo "❌  OpenSSL not found in pkg-config.";
        echo ""
        echo "ℹ️  'pkg-config openssl --cflags' did not contain any include flags";
        echo "This error is unexpected. Try restarting your terminal."
        echo "";
        help;
        exit 1;
    fi

    echo "✅  OpenSSL available"
}

# Run the compatibility script first
# eval "$(curl -sL check2.vapor.sh)";
./compatibility.sh
if [[ $? == 0 ]]; 
then 
    run
fi

