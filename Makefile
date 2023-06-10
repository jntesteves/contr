version := 0.4.0-pre
app_name := contr
build_dir := dist
app_files := contr.template.sh entrypoint.sh
PREFIX := ~/.local

$(build_dir): $(app_files)
	./build.sh $(app_name) $@ $(version)

.PHONY: install
install:
	install -DZ -m 755 -t $(PREFIX)/bin $(build_dir)/$(app_name)

.PHONY: uninstall
uninstall:
	rm -f $(PREFIX)/bin/$(app_name)

.PHONY: lint
lint:
	shellcheck ./*.sh $(build_dir)/$(app_name) make
	shfmt -p -i 4 -ci -d ./*.sh $(build_dir)/$(app_name) make

.PHONY: format
format:
	shfmt -p -i 4 -ci -w ./*.sh make

.PHONY: develop-image
develop-image:
	podman build -f Containerfile.develop -t contr-develop
