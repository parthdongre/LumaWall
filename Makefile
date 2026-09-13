.PHONY: run build test clean package install

run:
	swift run LumaWall

build:
	swift build

test:
	swift test

clean:
	rm -rf .build dist

package:
	./scripts/package-macos.sh

install:
	./scripts/install-local.sh
