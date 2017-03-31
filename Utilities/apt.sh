function add_vapor_apt() {
    eval "$(cat /etc/lsb-release)"

    if [[ "$DISTRIB_CODENAME" != "xenial" && "$DISTRIB_CODENAME" != "yakkety" && "$DISTRIB_CODENAME" != "trusty" ]];
    then
        echo "Only Ubuntu 14.04, 16.04, and 16.10 are supported."
        echo "You are running $DISTRIB_RELEASE ($DISTRIB_CODENAME) [`uname`]"
        return 1;
    fi

    export DEBIAN_FRONTEND=noninteractive

    sudo apt-get -q update
    sudo apt-get -q install -y wget software-properties-common python-software-properties apt-transport-https
    wget -q https://repo.vapor.codes/apt/keyring.gpg -O- | sudo apt-key add -
    echo "deb https://repo.vapor.codes/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/vapor.list
    sudo apt-get -q update

    unset DEBIAN_FRONTEND
}

add_vapor_apt;
