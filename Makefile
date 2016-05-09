PACKAGE = coreutils
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PATH_FLAGS = --prefix=/usr --sysconfdir=/etc --infodir=/tmp/trash --libexecdir=/usr/lib
CONF_FLAGS = --enable-no-install-program=groups,hostname,kill,uptime --with-openssl
CFLAGS =

OPENSSL_VERSION = 1.0.2h-7
OPENSSL_URL = https://github.com/amylum/openssl/releases/download/$(OPENSSL_VERSION)/openssl.tar.gz
OPENSSL_TAR = /tmp/openssl.tar.gz
OPENSSL_DIR = /tmp/openssl
OPENSSL_PATH = -I$(OPENSSL_DIR)/usr/include -L$(OPENSSL_DIR)/usr/lib

.PHONY : default submodule build_container manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

build_container:
	docker build -t coreutils-pkg meta

manual: submodule build_container
	./meta/launch /bin/bash || true

container: build_container
	./meta/launch

deps:
	rm -rf $(OPENSSL_DIR) $(OPENSSL_TAR)
	mkdir $(OPENSSL_DIR)
	curl -sLo $(OPENSSL_TAR) $(OPENSSL_URL)
	tar -x -C $(OPENSSL_DIR) -f $(OPENSSL_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	rm -rf $(BUILD_DIR)/.git
	cp -R .git/modules/upstream $(BUILD_DIR)/.git
	sed -i '/worktree/d' $(BUILD_DIR)/.git/config
	cd $(BUILD_DIR) && ./bootstrap
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(OPENSSL_PATH)' FORCE_UNSAFE_CONFIGURE=1 ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -r $(RELEASE_DIR)/tmp $(RELEASE_DIR)/usr/lib/charset.alias
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

