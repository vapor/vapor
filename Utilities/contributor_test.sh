echo "💧  Running unit tests on macOS"
swift test
MACOS_EXIT=$?

echo "💧  Starting docker-machine"
docker-machine start default

echo "💧  Exporting docker-machine env"
eval "$(docker-machine env default)"

echo "💧  Running unit tests on Linux"
docker run -it -v $PWD:/root/code -w /root/code norionomura/swift:swift-4.1-branch /usr/bin/swift test
LINUX_EXIT=$?

if [[ $MACOS_EXIT == 0 ]];
then
	echo "✅  macOS Passed"
else
	echo "🚫  macOS Failed"
fi

if [[ $LINUX_EXIT == 0 ]];
then
	echo "✅  Linux Passed"
else
	echo "🚫  Linux Failed"
fi
