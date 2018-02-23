function add_vapor_apt() {
    eval "$(cat /etc/lsb-release)"

    if [[ "$DISTRIB_CODENAME" != "xenial" && "$DISTRIB_CODENAME" != "yakkety" && "$DISTRIB_CODENAME" != "trusty" ]];
    then
        echo "Only Ubuntu 14.04, 16.04, and 16.10 are supported."
        echo "You are running $DISTRIB_RELEASE ($DISTRIB_CODENAME) [`uname`]"
        return 1;
    fi

    export DEBIAN_FRONTEND=noninteractive

    if ! [ $(id -u) = 0 ]; then
        export SUDO=sudo
    fi
    
    $SUDO apt-get -q update
    $SUDO apt-get -q install -y wget software-properties-common python-software-properties apt-transport-https
    wget -q https://repo.vapor.codes/apt/keyring.gpg -O- | $SUDO apt-key add -
    echo "deb https://repo.vapor.codes/apt $DISTRIB_CODENAME main" | $SUDO tee /etc/apt/sources.list.d/vapor.list
    $SUDO apt-get -q update

    unset DEBIAN_FRONTEND
    unset SUDO
}

add_vapor_apt;
