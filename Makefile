.PHONY: doctor run build test clean package install

doctor:
	bash scripts/doctor.sh

run: doctor
	swift run LumaWall

build: doctor
	swift build

test: doctor
	swift test

clean:
	rm -rf .build dist

package: doctor
	./scripts/package-macos.sh

install: doctor
	./scripts/install-local.sh
