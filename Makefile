run: build
	export LD_LIBRARY_PATH=.build; \
	.build/VaporApp

build: build_vapor
	cd .build; \
	swiftc ../Sources/VaporDev/main.swift ../Sources/VaporDev/**/*.swift -I . -L . -lVapor -lJay -lHummingbird -llibc -lStrand -o VaporApp

build_vapor: build_hummingbird build_jay build_vapor_libc
	cd .build; \
	swiftc ../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L .

build_vapor_libc: fetch
	cd .build; \
	swiftc ../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .

build_jay: fetch
	cd .build; \
	swiftc ../Packages/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .

build_hummingbird: build_strand
	cd .build; \
	swiftc ../Packages/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . 

build_strand: fetch
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

