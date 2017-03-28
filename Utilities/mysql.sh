#!/bin/sh

echo "📦  Vapor MySQL Quick Start"

function help() {
    echo "📖  Visit our docs for step-by-step instructions on installing Swift correctly."
    echo "http://docs.vapor.codes"
    echo ""
    echo "👋  or Join our Slack and we'll help you get setup."
    echo "http://vapor.team"
}

function check_mysql() {
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
        echo "Run this script again to continue MySQL quickstart.";
        return 1;
    fi

    VAPOR_PKG_CONFIG_PATH="/usr/local/share/vapor/pkgconfig";
    mkdir -p $VAPOR_PKG_CONFIG_PATH;

    MODULE_NAME="cmysql"
    MYSQL_PACKAGE_CONFIG="$VAPOR_PKG_CONFIG_PATH/$MODULE_NAME.pc";

    MYSQL_PREFIX="/usr/local/opt/mysql"

    echo "prefix=$MYSQL_PREFIX" > $MYSQL_PACKAGE_CONFIG;
    echo "exec_prefix=\${prefix}" >> $MYSQL_PACKAGE_CONFIG;
    echo "libdir=\${exec_prefix}/lib" >> $MYSQL_PACKAGE_CONFIG;
    echo "includedir=\${prefix}/include/mysql" >> $MYSQL_PACKAGE_CONFIG;
    echo "Name: MySQL" >> $MYSQL_PACKAGE_CONFIG;
    echo "Description: MySQL client library" >> $MYSQL_PACKAGE_CONFIG;
    echo "Version: 2.0" >> $MYSQL_PACKAGE_CONFIG;
    echo "Cflags: -I\${includedir}" >> $MYSQL_PACKAGE_CONFIG;
    echo "Libs: -L\${libdir} -lmysqlclient" >>  $MYSQL_PACKAGE_CONFIG;

    echo "Checking compatibility with MySQL..."

        # Check to make sure OpenSSL is installed
    BREW_PACKAGES=`brew list`;
    if [[ $BREW_PACKAGES != *"mysql"* ]];
    then
        echo "❌  MySQL not installed.";
        echo "";
        echo "📦  Run to install:";
        echo "brew install mysql";
        echo "";
        help;
        return 1; 
    fi

    MYSQL_VERSION=`ls /usr/local/Cellar/mysql/`;
    MYSQL_VERSION_DESIRED="5.7"
    if [[ $MYSQL_VERSION != *"$MYSQL_VERSION_DESIRED"* ]];
    then
        echo "❌  MySQL $MYSQL_VERSION_DESIRED required.";
        echo ""
        echo "ℹ️  Curent version: $MYSQL_VERSION";
        echo "";
        echo "📦  Run to update:";
        echo "brew upgrade mysql";
        echo "";
        help;
        return 1; 
    fi

    PKG_CONFIG_ALL=`pkg-config $MODULE_NAME --cflags`;
    if [[ $PKG_CONFIG_ALL != *"-I$MYSQL_PREFIX"* ]];
    then
        echo "";
        echo "❌  MySQL not found in pkg-config.";
        echo ""
        echo "ℹ️  'pkg-config $MODULE_NAME --cflags' did not contain any include flags";
        echo "This error is unexpected. Try restarting your terminal."
        echo "";
        help;
        return 1;
    fi

    echo "✅  MySQL available"
}

echo "Checking compatibility with Vapor..."

# Run the compatibility script first
eval "$(curl -sL check2.vapor.sh)";
if [[ $? == 0 ]]; 
then 
    check_mysql;
fi

