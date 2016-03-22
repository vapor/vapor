.PHONY: clean

pwd = $(shell pwd)

.build/VaporApp: .build/libVapor.so Sources/VaporDev/main.swift Sources/VaporDev/**/*.swift
	swiftc Sources/VaporDev/**.swift -I .build -L .build -lVapor -lJay -lHummingbird -llibc -lStrand -Xlinker -rpath -Xlinker $(pwd)/.build -o .build/VaporApp

run: make
	.build/VaporApp
	
.build/libVapor.so: .build/libHummingbird.so .build/libJay.so .build/liblibc.so
	cd .build; \
	swiftc ../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L .

.build/liblibc.so: 
	cd .build; \
	swiftc ../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .

.build/libJay.so: Packages/Jay/Sources/Jay/*.swift
	cd .build; \
	swiftc ../Packages/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .

.build/libHummingbird.so: .build/libStrand.so Packages/Hummingbird/Sources/*.swift
	cd .build; \
	swiftc ../Packages/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . 

.build/libStrand.so: Packages/Strand/Sources/*.swift
	mkdir .build; \
	cd .build; \
	swiftc ../Packages/Strand/Sources/*.swift -emit-library -emit-module -module-name Strand

Packages/Strand/Sources/*.swift:
	git clone https://github.com/ketzusaka/Strand Packages/Strand;

Packages/Jay/Sources/Jay/*.swift:
	git clone https://github.com/qutheory/json Packages/Jay

Packages/Hummingbird/Sources/*.swift:
	git clone https://github.com/ketzusaka/Hummingbird Packages/Hummingbird

.build:
	mkdir .build

clean:
	rm -rf Packages
	rm -rf .build

