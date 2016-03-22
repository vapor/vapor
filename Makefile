.PHONY: fetch clean prepare

pwd = $(shell pwd)

make: .build/libVapor.so
	cd .build; \
	swiftc ../Sources/VaporDev/main.swift ../Sources/VaporDev/**/*.swift -I . -L . -lVapor -lJay -lHummingbird -llibc -lStrand -Xlinker -rpath -Xlinker $(pwd)/.build -o VaporApp

run: make
	.build/VaporApp
	

.build/libVapor.so: .build/libHummingbird.so .build/libJay.so .build/liblibc.so
	cd .build; \
	swiftc ../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L .

.build/liblibc.so: 
	cd .build; \
	swiftc ../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .

.build/libJay.so:
	cd .build; \
	swiftc ../Packages/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .

.build/libHummingbird.so: .build/libStrand.so
	cd .build; \
	swiftc ../Packages/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . 

.build/libStrand.so:
	cd .build; \
	swiftc ../Packages/Strand/Sources/*.swift -emit-library -emit-module -module-name Strand

clean:
	rm -rf Packages
	rm -rf .build

prepare: 
	mkdir Packages
	mkdir .build

fetch: clean prepare
	git clone https://github.com/ketzusaka/Strand Packages/Strand;
	git clone https://github.com/ketzusaka/Hummingbird Packages/Hummingbird
	git clone https://github.com/qutheory/json Packages/Jay

