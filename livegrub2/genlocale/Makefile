PACKAGE = genlocale
POFILES = $(wildcard po/*.po)
MOFILES = $(POFILES:.po=.mo)
POTFILE = po/$(PACKAGE).pot
LOCALEDIR = locale

all: build

build: buildmo

buildmo: $(MOFILES)

%.mo : %.po
	echo "Compiling $<"
	msgfmt -f $< -o $@

install: build installmo

installmo:
	for j in $(MOFILES); do \
		install -d -m 755 \
			$(LOCALEDIR)/`basename $$j|sed "s/.mo//"`/LC_MESSAGES \
			2> /dev/null; \
		install -m 644 $$j \
			$(LOCALEDIR)/`basename $$j|sed "s/.mo//"`/LC_MESSAGES/$(PACKAGE).mo; \
	done
	

clean:
	rm -f $(MOFILES)
	rm -f $(POFILES:.po=.po~)

uninstall:
	rm -f $(LOCALEDIR)/*/LC_MESSAGES/$(PACKAGE).mo
	rmdir -p $(LOCALEDIR)/*/LC_MESSAGES/ 2>/dev/null || true

updatepo:
	touch $(POTFILE)
	xgettext --from-code=utf-8 \
		-j \
		-L Python \
		-o $(POTFILE) \
		$(PACKAGE)
	for i in $(POFILES); do \
		msgmerge -U $$i $(POTFILE); \
	done

.PHONY: clean uninstall installmo updatepo
