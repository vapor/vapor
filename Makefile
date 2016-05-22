.PHONY: build enter

SWIFT_VERSION=`cat .swift-version`
IMG=qutheory/swift:$(SWIFT_VERSION)

build:
	docker build --rm -t $(IMG) --build-arg SWIFT_VERSION=$(SWIFT_VERSION) .

enter:
	docker run -it --rm --privileged=true --entrypoint bash $(IMG)

run:
	docker run --rm -it --privileged=true $(IMG)
