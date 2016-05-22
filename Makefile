.PHONY: build enter

SWIFTVERSION=`cat .swift-version`
IMG=qutheory/swift:$(SWIFTVERSION)

build:
	docker build --rm -t $(IMG) .

enter:
	docker run -it --rm --privileged=true --entrypoint bash $(IMG)

run:
	docker run --rm -it --privileged=true $(IMG)
