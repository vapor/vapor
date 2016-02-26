build:
	@echo "Building Vapor"
	@swift build

fresh-build: clean build

fresh-test: fresh-build test

fresh-run: fresh-build run

test: build
	@echo "Testing Vapor"
	@swift test

debug: build
	@echo "Debugging VaporDev"
	@lldb .build/debug/VaporDev

build-release:
	@echo "Building Vapor in Release"
	@swift build --configuration release

run: build
	@echo "Running VaporDev"
	.build/debug/VaporDev

clean:
	rm -fr .build Packages