platform=`uname`

if [[ $platform == 'Linux' ]]; then
	wget https://swift.org/builds/swift-2.2-release/ubuntu1404/swift-2.2-RELEASE/swift-2.2-RELEASE-ubuntu14.04.tar.gz
	export PATH=swift-2.2-RELEASE-ubuntu14.04/usr/bin/:"${PATH}"
	make
fi
