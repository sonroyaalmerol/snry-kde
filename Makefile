NAME := snry-kde
VERSION ?= $(shell scripts/version.sh 2>/dev/null || cat VERSION)
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
DESTDIR ?=

KWIN_ID := snry-workspaces
PLASMOID_ID := me.snry.htpc
BIN := snry-htpc snry-kde-setup
DIST := dist

SUBST = sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@BINDIR@|$(BINDIR)|g' -e 's|@DATADIR@|$(DATADIR)/$(NAME)|g'

.PHONY: all install uninstall dist kwinscript plasmoid packages check clean version

all:
	@echo "Targets: install, uninstall, dist, kwinscript, plasmoid, packages, check (VERSION=$(VERSION))"

version:
	@echo $(VERSION)

define install_tree
	cd $(1) && find . -type d -exec install -d "$(2)/{}" \;
	cd $(1) && find . -type f ! -name metadata.json -exec install -m644 "{}" "$(2)/{}" \;
	$(SUBST) $(1)/metadata.json > "$(2)/metadata.json"
	chmod 644 "$(2)/metadata.json"
endef

install:
	install -d "$(DESTDIR)$(BINDIR)"
	for b in $(BIN); do $(SUBST) bin/$$b > "$(DESTDIR)$(BINDIR)/$$b"; chmod 755 "$(DESTDIR)$(BINDIR)/$$b"; done
	install -d "$(DESTDIR)$(DATADIR)/kwin/scripts/$(KWIN_ID)"
	$(call install_tree,kwin/$(KWIN_ID),$(abspath $(DESTDIR)$(DATADIR))/kwin/scripts/$(KWIN_ID))
	install -d "$(DESTDIR)$(DATADIR)/plasma/plasmoids/$(PLASMOID_ID)"
	$(call install_tree,plasmoid/$(PLASMOID_ID),$(abspath $(DESTDIR)$(DATADIR))/plasma/plasmoids/$(PLASMOID_ID))
	install -d "$(DESTDIR)$(DATADIR)/applications"
	$(SUBST) share/applications/$(PLASMOID_ID).desktop > "$(DESTDIR)$(DATADIR)/applications/$(PLASMOID_ID).desktop"
	chmod 644 "$(DESTDIR)$(DATADIR)/applications/$(PLASMOID_ID).desktop"
	install -Dm644 share/snry-kde/shortcuts.conf "$(DESTDIR)$(DATADIR)/$(NAME)/shortcuts.conf"
	install -Dm644 share/snry-kde/snry-htpcrc.example "$(DESTDIR)$(DATADIR)/$(NAME)/snry-htpcrc.example"
	install -Dm644 README.md "$(DESTDIR)$(DATADIR)/doc/$(NAME)/README.md"

uninstall:
	for b in $(BIN); do rm -f "$(DESTDIR)$(BINDIR)/$$b"; done
	rm -rf "$(DESTDIR)$(DATADIR)/kwin/scripts/$(KWIN_ID)" "$(DESTDIR)$(DATADIR)/plasma/plasmoids/$(PLASMOID_ID)"
	rm -f "$(DESTDIR)$(DATADIR)/applications/$(PLASMOID_ID).desktop"
	rm -rf "$(DESTDIR)$(DATADIR)/$(NAME)" "$(DESTDIR)$(DATADIR)/doc/$(NAME)"

dist:
	rm -rf "$(DIST)/$(NAME)-$(VERSION)"
	mkdir -p "$(DIST)/$(NAME)-$(VERSION)"
	git ls-files -z | xargs -0 -I{} cp --parents "{}" "$(DIST)/$(NAME)-$(VERSION)/"
	echo "$(VERSION)" > "$(DIST)/$(NAME)-$(VERSION)/VERSION"
	printf '#!/bin/sh\ncat "$$(dirname "$$0")/../VERSION"\n' > "$(DIST)/$(NAME)-$(VERSION)/scripts/version.sh"
	tar -C "$(DIST)" -czf "$(DIST)/$(NAME)-$(VERSION).tar.gz" "$(NAME)-$(VERSION)"
	rm -rf "$(DIST)/$(NAME)-$(VERSION)"
	@echo "$(DIST)/$(NAME)-$(VERSION).tar.gz"

define zip_package
	rm -rf "$(DIST)/.stage-$(2)"
	mkdir -p "$(DIST)/.stage-$(2)"
	cp -r $(1)/. "$(DIST)/.stage-$(2)/"
	$(SUBST) $(1)/metadata.json > "$(DIST)/.stage-$(2)/metadata.json"
	rm -f "$(DIST)/$(2)"
	cd "$(DIST)/.stage-$(2)" && python3 -m zipfile -c "../$(2)" *
	rm -rf "$(DIST)/.stage-$(2)"
	@echo "$(DIST)/$(2)"
endef

kwinscript:
	mkdir -p $(DIST)
	$(call zip_package,kwin/$(KWIN_ID),$(KWIN_ID)-$(VERSION).kwinscript)

plasmoid:
	mkdir -p $(DIST)
	$(call zip_package,plasmoid/$(PLASMOID_ID),$(PLASMOID_ID)-$(VERSION).plasmoid)

packages: dist kwinscript plasmoid

check:
	bash -n bin/snry-htpc bin/snry-kde-setup scripts/version.sh
	if command -v shellcheck >/dev/null; then shellcheck -S warning bin/snry-htpc bin/snry-kde-setup scripts/version.sh; fi
	if command -v node >/dev/null; then node --check kwin/$(KWIN_ID)/contents/code/main.js; fi
	for f in kwin/$(KWIN_ID)/metadata.json plasmoid/$(PLASMOID_ID)/metadata.json; do jq empty "$$f"; done
	if command -v desktop-file-validate >/dev/null; then desktop-file-validate share/applications/$(PLASMOID_ID).desktop; fi

clean:
	rm -rf $(DIST)
