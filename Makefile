.PHONY: all build run app dmg test clean landing

all: app

build:
	swift build

run: app
	./build/OrcaNotes.app/Contents/MacOS/OrcaNotes

app:
	./scripts/build_app.sh

dmg:
	./scripts/package_dmg.sh

test:
	swift test

landing:
	open landing/index.html

clean:
	rm -rf .build build
