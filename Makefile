.PHONY: clean run install

OS = $(shell uname)
PWD = $(shell pwd)

ifeq "$(OS)" "Darwin"
	SWIFTC = xcrun -sdk macosx swiftc
	LIBHUMMINGBIRD = .build/libHummingbird.dylib
	LIBJAY = .build/libJay.dylib
	LIBSTRAND = .build/libStrand.dylib
	LIBLIBC = .build/liblibc.dylib
	LIBVAPOR = .build/libVapor.dylib
	RUN = cd .build; ./VaporApp; cd ../
else
	SWIFTC = swiftc
	LIBHUMMINGBIRD = .build/libHummingbird.so
	LIBJAY = .build/libJay.so
	LIBSTRAND = .build/libStrand.so
	LIBLIBC = .build/liblibc.so
	LIBVAPOR = .build/libVapor.so
	RUN = .build/VaporApp
endif


.build/VaporApp: $(LIBVAPOR) Sources/VaporDev/main.swift Sources/VaporDev/**/*.swift
	$(EXPORT)
	$(SWIFTC) Sources/VaporDev/**.swift -I .build -L $(PWD)/.build -lVapor -lJay -lHummingbird -llibc -lStrand -Xlinker -rpath -Xlinker $(PWD)/.build -o .build/VaporApp

run: .build/VaporApp
	$(RUN);

install: $(LIBVAPOR)
	mkdir /usr/local/opt; \
	mkdir /usr/local/opt/vapor; \
	mkdir /usr/local/opt/vapor/lib; \
	mkdir /usr/local/opt/vapor/include; \
	cp -R .build/lib* /usr/local/opt/vapor/lib; \
	cp -R .build/*.swiftdoc /usr/local/opt/vapor/include; \
	cp -R .build/*.swiftmodule /usr/local/opt/vapor/include; \
	
$(LIBVAPOR): $(LIBHUMMINGBIRD) $(LIBJAY) $(LIBLIBC) Sources/Vapor/**/*.swift
	mkdir .build; \
	cd .build; \
	$(SWIFTC) ../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L . -lJay -lHummingbird -llibc -lStrand

$(LIBLIBC): 
	mkdir .build; \
	cd .build; \
	$(SWIFTC) ../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .

$(LIBJAY): Packages/Jay/Sources/Jay/*.swift
	mkdir .build; \
	cd .build; \
	$(SWIFTC) ../Packages/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .

$(LIBHUMMINGBIRD): $(LIBSTRAND) Packages/Hummingbird/Sources/*.swift
	mkdir .build; \
	cd .build; \
	$(SWIFTC) ../Packages/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . -lStrand

$(LIBSTRAND): Packages/Strand/Sources/*.swift
	mkdir .build; \
	cd .build; \
	$(SWIFTC) ../Packages/Strand/Sources/*.swift -emit-library -emit-module -module-name Strand

Packages/Strand/Sources/*.swift:
	git clone https://github.com/ketzusaka/Strand Packages/Strand; \
	cd Packages/Strand; \
	git checkout 1.0.2

Packages/Jay/Sources/Jay/*.swift:
	git clone https://github.com/qutheory/json Packages/Jay

Packages/Hummingbird/Sources/*.swift:
	git clone https://github.com/ketzusaka/Hummingbird Packages/Hummingbird; \
	cd Packages/Hummingbird; \
	git checkout 1.0.3

clean:
	rm -rf Packages
	rm -rf .build

