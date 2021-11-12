PACKAGE_NAME := casetools
PACKAGE_VERSION := $(shell bash -c '. src/lib/$(PACKAGE_NAME) 2>/dev/null; casetools::version')
INSTALL_PATH := $(shell python -c 'import sys; sys.stdout.write("{}\n".format(sys.prefix)) if hasattr(sys, "real_prefix") or hasattr(sys, "base_prefix") else exit(255)' 2>/dev/null || echo "/usr/local")
LIB_COMPONENTS := $(wildcard src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/*)
BIN_COMPONENTS := $(foreach name, $(wildcard src/bin/*), build/bin/$(notdir $(name)))
PNG_COMPONENTS := $(wildcard src/png/*)
DIR_COMPONENTS := $(foreach name, bin share lib, build/$(name)) packages tools
DEBIAN_ARCHIVE := packages/$(PACKAGE_NAME)-$(PACKAGE_VERSION).deb

.PHONY: tests clean help

all: build

help:
	@echo "Usage: make build|tests|all|clean|version|install"

build: build/lib/$(PACKAGE_NAME) build/share/$(PACKAGE_NAME)/png $(BIN_COMPONENTS)

deb: $(DEBIAN_ARCHIVE)

$(DEBIAN_ARCHIVE): build packages tools/debianizer
	@tools/debianizer \
		--source=build \
		--root=/usr/local \
		--target="$@" \
		--package="$(PACKAGE_NAME)" \
		--version="$(PACKAGE_VERSION)"

	@dpkg --info $@
	@dpkg --contents $@

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
	src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/virtualenv \
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

#=======================================================================
#
#=======================================================================
src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/option_parsing: checkouts/optionslib
	@cd $< && make all
	@cp $</build/lib/optionslib-$$($</build/bin/optionslib --version)/parse $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/logging: checkouts/bashlib
	@cd $< && make all
	@cp $</build/lib/bashLib-$$($</build/bin/bashlib --version)/logging $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/settings: checkouts/bashlib
	@cd $< && make all
	@cp $</build/lib/bashLib-$$($</build/bin/bashlib --version)/settings $@

src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/virtualenv: checkouts/bashlib
	@cd $< && make all
	@cp $</build/lib/bashLib-$$($</build/bin/bashlib --version)/virtualenv $@

tools/debianizer: checkouts/packagetools tools
	@cp $</source/bin/$(notdir $@) $@

#=======================================================================
#
#=======================================================================
checkouts/optionslib:
	@git clone https://github.com/damionw/optionslib.git $@

checkouts/bashlib:
	@git clone https://github.com/damionw/bashlib.git $@

checkouts/packagetools: checkouts
	@(cd "$@" >/dev/null 2>&1 && git pull) || git clone -q http://git:git@git/Packages/Development/PackagingTools.git $@ || true

#=======================================================================
#
#=======================================================================
$(DIR_COMPONENTS):
	@install -d $@
