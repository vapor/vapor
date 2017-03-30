function add_vapor_apt() {
    eval "$(cat /etc/lsb-release)"

    if [[ "$DISTRIB_CODENAME" != "xenial" && "$DISTRIB_CODENAME" != "yakkety" ]];
    then
        echo "Only Ubuntu 16.04 (Xenial) and 16.10 (Yakkety) are supported."
        echo "You are running $DISTRIB_RELEASE ($DISTRIB_CODENAME) [`uname`]"
        exit 1;
    fi

    sudo apt-get update
    sudo apt-get install wget software-properties-common python-software-properties apt-transport-https
    wget -q https://repo.vapor.codes/apt/keyring.gpg -O- | sudo apt-key add -
    echo "deb https://repo.vapor.codes/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/vapor.list
    sudo apt-get update
}

add_vapor_apt;
