version := 0.2.3-pre
app_name := contr
build_dir := dist
app_files := contr.template.sh entrypoint.sh
ifdef PREFIX
install_prefix := $(PREFIX)
else
install_prefix := ~/.local
endif

$(build_dir): $(app_files)
	./build.sh $(app_name) $@ $(version)

.PHONY: install
install:
	install -DZ -m 755 -t $(install_prefix)/bin $(build_dir)/$(app_name)

.PHONY: uninstall
uninstall:
	rm -f $(install_prefix)/bin/$(app_name)

.PHONY: lint
lint:
	shellcheck *.sh $(build_dir)/$(app_name)
	shfmt -p -i 4 -ci -d *.sh $(build_dir)/$(app_name)

.PHONY: format
format:
	shfmt -p -i 4 -ci -w *.sh

.PHONY: develop-image
develop-image:
	podman build -f Containerfile.develop -t contr-develop
