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
    wget -q https://repo.vapor.codes/apt/public.gpg -O- | sudo apt-key add -
    sudo add-apt-repository "deb https://repo.vapor.codes/apt $DISTRIB_CODENAME main"
}

add_vapor_apt;
