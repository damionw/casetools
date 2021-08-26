PACKAGE_NAME := casetools
PACKAGE_VERSION := $(shell bash -c '. src/lib/$(PACKAGE_NAME) 2>/dev/null; casetools::version')
INSTALL_PATH := $(shell python -c 'import sys; print sys.prefix if hasattr(sys, "real_prefix") else exit(255)' 2>/dev/null || echo "/usr/local")
LIB_COMPONENTS := $(wildcard src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/*)
BIN_COMPONENTS := $(foreach name, $(wildcard src/bin/*), build/bin/$(notdir $(name)))
PNG_COMPONENTS := $(wildcard src/png/*)
DIR_COMPONENTS := $(foreach name, bin share lib, build/$(name)) packages
DEBIAN_ARCHIVE := packages/$(PACKAGE_NAME)-$(PACKAGE_VERSION).deb
UPLOAD_REPO := /repository/share/Software/Platform/linux/private

.PHONY: tests clean help

all: build

help:
	@echo "Usage: make build|tests|all|clean|version|install"

build: build/lib/$(PACKAGE_NAME) build/share/$(PACKAGE_NAME)/png $(BIN_COMPONENTS)

deb: $(DEBIAN_ARCHIVE)

upload: deb
	@rsync -avz $(DEBIAN_ARCHIVE) $(UPLOAD_REPO)/

$(DEBIAN_ARCHIVE): build packages
	@debianizer \
		--source=build \
		--root=/usr/local \
		--target="$@" \
		--package="$(PACKAGE_NAME)" \
		--version="$(PACKAGE_VERSION)"

install-private: tests $(HOME)/bin
	@echo "Privately installing into directory '$(HOME)'"
	@echo $$PATH | tr '\\:' '\n' | grep -q '^'"$$HOME/bin"'$$'
	@rsync -az build/ $(HOME)/

install: tests
	@echo "Installing into directory '$(INSTALL_PATH)'"
	@rsync -az build/ $(INSTALL_PATH)/

version: build
	@build/bin/casetool --version

tests: build
	@PATH="$(shell readlink -f build/bin):$(PATH)" unittests/testsuite

clean:
	-@rm -rf build

realclean: clean
	-@rm -rf checkouts

build/lib/$(PACKAGE_NAME): build/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION) build/lib src/lib/$(PACKAGE_NAME) \
	src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/option_parsing \
	src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/settings \
	src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/logging
	@install -m 755 src/lib/$(PACKAGE_NAME) $@

build/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION): build/lib $(LIB_COMPONENTS)
	@rsync -az src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/ $@/

build/share/$(PACKAGE_NAME): build/share
	@install -d $@

build/share/$(PACKAGE_NAME)/png: build/share/$(PACKAGE_NAME) $(PNG_COMPONENTS)
	@rsync -az src/png/ $@/

build/bin/%: build/lib/$(PACKAGE_NAME) build/bin | src/bin
	@install -m 755 src/bin/$(notdir $@) $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/option_parsing: checkouts/optionslib
	@cd $< && make all
	@cp $</build/lib/optionslib-$$($</build/bin/optionslib --version)/parse $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/logging: checkouts/bashlib
	@cd $< && make all
	@cp $</build/lib/bashLib-$$($</build/bin/bashlib --version)/logging $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/settings: checkouts/bashlib
	@cd $< && make all
	@cp $</build/lib/bashLib-$$($</build/bin/bashlib --version)/settings $@

checkouts/optionslib:
	@git clone https://github.com/damionw/optionslib.git $@

checkouts/bashlib:
	@git clone https://github.com/damionw/bashlib.git $@

$(DIR_COMPONENTS):
	@install -d $@
