#!/bin/sh

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
}

function check_openssl() {
    OS=`uname`
    if [[ $OS != "Darwin" ]]; # macOS
    then
        echo "❌  This script is for macOS only."
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

    echo "Checking compatibility with Package Config..."
    eval "$(curl -sL https://pkgconfig.vapor.sh)";
    if [[ $? != 0 ]]; 
    then 
        echo "Run this script again to continue OpenSSL quickstart.";
        return 1;
    fi

    VAPOR_PKG_CONFIG_PATH="/usr/local/share/vapor/pkgconfig";
    mkdir -p $VAPOR_PKG_CONFIG_PATH;

    OPENSSL_PKG_CONFIG="$VAPOR_PKG_CONFIG_PATH/ctls.pc";

    OPENSSL_PREFIX="/usr/local/opt/openssl"

    echo "prefix=$OPENSSL_PREFIX" > $OPENSSL_PKG_CONFIG;
    echo "exec_prefix=\${prefix}" >> $OPENSSL_PKG_CONFIG;
    echo "libdir=\${exec_prefix}/lib" >> $OPENSSL_PKG_CONFIG;
    echo "includedir=\${prefix}/include" >> $OPENSSL_PKG_CONFIG;
    echo "Name: CTLS" >> $OPENSSL_PKG_CONFIG;
    echo "Description: LibreSSL / OpenSSL module map for Swift" >> $OPENSSL_PKG_CONFIG;
    echo "Version: 1.0" >> $OPENSSL_PKG_CONFIG;
    echo "Requires: libssl libcrypto" >> $OPENSSL_PKG_CONFIG;
    echo "Cflags: -I\${includedir}" >> $OPENSSL_PKG_CONFIG;
    echo "Libs: -L\${libdir} -lssl" >>  $OPENSSL_PKG_CONFIG;

    PROFILE="$HOME/.bash_profile"
    PKG_CONFIG_EXPORT="export PKG_CONFIG_PATH=$VAPOR_PKG_CONFIG_PATH:\$PKG_CONFIG_PATH"


    echo "Checking compatibility with OpenSSL..."

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
        return 1; 
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
        return 1; 
    fi

    PKG_CONFIG_ALL=`pkg-config ctls --cflags`;
    if [[ $PKG_CONFIG_ALL != *"-I$OPENSSL_PREFIX"* ]];
    then
        echo "";
        echo "❌  OpenSSL not found in pkg-config.";
        echo ""
        echo "ℹ️  'pkg-config ctls --cflags' did not contain any include flags";
        echo "This error is unexpected. Try restarting your terminal."
        echo "";
        help;
        return 1;
    fi

    echo "✅  OpenSSL available"
}

# Run the compatibility script first
eval "$(curl -sL check2.vapor.sh)";
if [[ $? == 0 ]]; 
then 
    check_openssl;
fi

