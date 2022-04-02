version = 0.1.0
app_name = contr
build_dir = target
app_files = contr.template.sh entrypoint.sh
ifdef PREFIX
install_prefix = $(PREFIX)
else
install_prefix = ~/.local
endif

$(build_dir): $(app_files)
	./build.sh $(app_name) $@ $(version)

.PHONY: install
install:
	cp $(build_dir)/$(app_name) $(install_prefix)/bin/$(app_name)

.PHONY: clean
clean:
	-rm -rf $(build_dir)/

.PHONY: uninstall
uninstall:
	rm -f $(install_prefix)/bin/$(app_name)

.PHONY: lint
lint:
	shellcheck --severity=style *.sh $(build_dir)/$(app_name)
	shfmt -p -i 4 -ci -d *.sh $(build_dir)/$(app_name)

.PHONY: format
format:
	shfmt -p -i 4 -ci -w *.sh
