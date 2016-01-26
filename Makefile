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
CFLAGS = -static -static-libgcc -Wl,-static -lc

.PHONY : default submodule build_container manual container build version push local

default: submodule container

submodule:
	git submodule update --init

build_container:
	docker build -t coreutils-pkg meta

manual: submodule build_container
	./meta/launch /bin/bash || true

container: build_container
	./meta/launch

build: submodule
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	rm -rf $(BUILD_DIR)/.git
	cp -R .git/modules/upstream $(BUILD_DIR)/.git
	sed -i '/worktree/d' $(BUILD_DIR)/.git/config
	cd $(BUILD_DIR) && ./bootstrap
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -r $(RELEASE_DIR)/tmp $(RELEASE_DIR)/usr/var
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

