.PHONY: doctor repair run build test verify clean package install

doctor:
	bash scripts/doctor.sh

repair:
	bash scripts/repair-dev.sh

run: doctor
	swift run LumaWall

build: doctor
	swift build

test: doctor
	swift test

verify: doctor
	swift build
	swift test
	swift build -c release

clean:
	rm -rf .build dist

package: doctor
	./scripts/package-macos.sh

install: doctor
	./scripts/install-local.sh
