.PHONY: clean run install release

OS = $(shell uname)
PWD = $(shell pwd)
ARCH = $(shell uname -m)

VERSION = 0.3.4

RELEASE_DIR = Release/$(VERSION)_$(OS)_$(ARCH)
DEBUG_DIR = .build
PACKAGES_DIR = Packages

STRAND_TAG = 1.0.2
HUMMINGBIRD_TAG = 1.0.3
JAY_TAG = 0.4.0

ifeq "$(OS)" "Darwin"
	SWIFTC = xcrun -sdk macosx swiftc
	LIBHUMMINGBIRD = $(DEBUG_DIR)/libHummingbird.dylib
	LIBJAY = $(DEBUG_DIR)/libJay.dylib
	LIBSTRAND = $(DEBUG_DIR)/libStrand.dylib
	LIBLIBC = $(DEBUG_DIR)/liblibc.dylib
	LIBVAPORNAME = libVapor.dylib
	LIBVAPOR = $(DEBUG_DIR)/libVapor.dylib
	RUN = cd $(DEBUG_DIR); ./VaporApp; cd ../
	SYSLIB = /usr/local/opt/vapor/lib
	SYSINCLUDE = /usr/local/opt/vapor/include
else
	SWIFTC = swiftc
	LIBHUMMINGBIRD = $(DEBUG_DIR)/libHummingbird.so
	LIBJAY = $(DEBUG_DIR)/libJay.so
	LIBSTRAND = $(DEBUG_DIR)/libStrand.so
	LIBLIBC = $(DEBUG_DIR)/liblibc.so
	LIBVAPORNAME = libVapor.so
	LIBVAPOR = $(DEBUG_DIR)/libVapor.so
	RUN = $(DEBUG_DIR)/VaporApp
	SYSLIB = /usr/local/lib
	SYSINCLUDE = /usr/local/include/vapor
endif


$(DEBUG_DIR)/VaporApp: $(LIBVAPOR) Sources/VaporDev/main.swift Sources/VaporDev/**/*.swift
	$(SWIFTC) Sources/VaporDev/**.swift -I $(DEBUG_DIR) -L $(PWD)/$(DEBUG_DIR) -lVapor -lJay -lHummingbird -llibc -lStrand -Xlinker -rpath -Xlinker $(PWD)/$(DEBUG_DIR) -o $(DEBUG_DIR)/VaporApp

run: $(DEBUG_DIR)/VaporApp
	$(RUN);

release: $(PACKAGES_DIR)/Strand/Sources/*.swift $(PACKAGES_DIR)/Jay/Sources/Jay/*.swift $(PACKAGES_DIR)/Hummingbird/Sources/*.swift
	mkdir -p $(RELEASE_DIR); \
	cd $(RELEASE_DIR); \
	$(SWIFTC) -O ../../$(PACKAGES_DIR)/Strand/Sources/*.swift -emit-library -emit-module -module-name Strand; \
	$(SWIFTC) -O ../../$(PACKAGES_DIR)/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . -lStrand; \
	$(SWIFTC) -O ../../$(PACKAGES_DIR)/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .; \
	$(SWIFTC) -O ../../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .; \
	$(SWIFTC) -O ../../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L . -lJay -lHummingbird -llibc -lStrand

install: $(RELEASE_DIR)/$(LIBVAPORNAME)
	mkdir -p $(SYSLIB); \
	mkdir -p $(SYSINCLUDE); \
	cp -R $(RELEASE_DIR)/lib* $(SYSLIB); \
	cp -R $(RELEASE_DIR)/*.swiftdoc $(SYSINCLUDE); \
	cp -R $(RELEASE_DIR)/*.swiftmodule $(SYSINCLUDE); \
	cp vapor /usr/local/bin
	
$(LIBVAPOR): $(LIBHUMMINGBIRD) $(LIBJAY) $(LIBLIBC) Sources/Vapor/**/*.swift
	mkdir -p $(DEBUG_DIR); \
	cd $(DEBUG_DIR); \
	$(SWIFTC) ../Sources/Vapor/**/*.swift -emit-library -emit-module -module-name Vapor -I . -L . -lJay -lHummingbird -llibc -lStrand

$(LIBLIBC): 
	mkdir -p $(DEBUG_DIR); \
	cd $(DEBUG_DIR); \
	$(SWIFTC) ../Sources/libc/*.swift -emit-library -emit-module -module-name libc -I . -L .

$(LIBJAY): $(PACKAGES_DIR)/Jay/Sources/Jay/*.swift
	mkdir -p $(DEBUG_DIR); \
	cd $(DEBUG_DIR); \
	$(SWIFTC) ../$(PACKAGES_DIR)/Jay/Sources/Jay/*.swift -emit-library -emit-module -module-name Jay -I . -L .

$(LIBHUMMINGBIRD): $(LIBSTRAND) $(PACKAGES_DIR)/Hummingbird/Sources/*.swift
	mkdir -p $(DEBUG_DIR); \
	cd $(DEBUG_DIR); \
	$(SWIFTC) ../$(PACKAGES_DIR)/Hummingbird/Sources/*.swift -emit-library -emit-module -module-name Hummingbird -I . -L . -lStrand

$(LIBSTRAND): $(PACKAGES_DIR)/Strand/Sources/*.swift
	mkdir -p $(DEBUG_DIR); \
	cd $(DEBUG_DIR); \
	$(SWIFTC) ../$(PACKAGES_DIR)/Strand/Sources/*.swift -emit-library -emit-module -module-name Strand

$(PACKAGES_DIR)/Strand/Sources/*.swift:
	git clone https://github.com/ketzusaka/Strand $(PACKAGES_DIR)/Strand; \
	cd $(PACKAGES_DIR)/Strand; \
	git checkout $(STRAND_TAG)

$(PACKAGES_DIR)/Jay/Sources/Jay/*.swift:
	git clone https://github.com/qutheory/json $(PACKAGES_DIR)/Jay; \
	cd $(PACKAGES_DIR)/Jay; \
	git checkout $(JAY_TAG)

$(PACKAGES_DIR)/Hummingbird/Sources/*.swift:
	git clone https://github.com/ketzusaka/Hummingbird $(PACKAGES_DIR)/Hummingbird; \
	cd $(PACKAGES_DIR)/Hummingbird; \
	git checkout $(HUMMINGBIRD_TAG)

clean:
	rm -rf $(PACKAGES_DIR)
	rm -rf $(DEBUG_DIR)
	rm -rf $(RELEASE_DIR)

