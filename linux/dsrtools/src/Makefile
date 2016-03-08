include ../mk/macros.mk

$(call varchklist_call,\
	DIST \
	INSTDIR \
	PACKAGE \
	RELEASE \
	VERSION)

rcfilebase = dsr
rcfile = $(rcfilebase)rc
cmdfile = dsrctl
servicefile = dsr.service
man5base = dsr.conf
man5file = $(man5base).5
man8base = dsrctl
man8file = $(man8base).8
confdir = dsr.d
readme = README

instrcfile   = $(INSTDIR)/etc/rc.d/init.d/$(rcfilebase)
instcmdfile  = $(INSTDIR)/usr/sbin/$(cmdfile)
instservicefile = $(INSTDIR)/usr/lib/systemd/system/$(servicefile)
instman5file  = $(INSTDIR)/usr/share/man/man5/$(man5file)
instman8file  = $(INSTDIR)/usr/share/man/man8/$(man8file)
instconfd =  $(INSTDIR)/etc/$(confdir)
instreadme =  $(INSTDIR)/etc/$(confdir)/$(readme)

ifeq ($(WITHSYSTEMD),1)
  rcfile=
  instrcfile=
else
  servicefile=
  instservicefile=
endif


all_targets = $(rcfile) \
	      $(cmdfile) \
	      $(servicefile) \
	      $(man5file) \
	      $(man8file)

install_targets = $(instrcfile) \
		  $(instcmdfile) \
		  $(instservicefile) \
		  $(instman5file) \
		  $(instman8file) \
		  $(instconfd) \
		  $(instreadme)

clean_targets = $(all_targets)

distclean_targets = $(clean_targets) $(topdir)

all: $(all_targets)

install: $(install_targets)

$(instrcfile): $(rcfile)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instcmdfile): $(cmdfile)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instservicefile): $(servicefile)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instman5file): $(man5file)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instman8file): $(man8file)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instreadme): $(readme)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

$(instconfd):
	mkdir -p -- '$@'

clean distclean:
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)

%: %.sh
	cp -fp -- '$<' '$@'
	chmod -w+x -- '$@'

%: %.sed
	rm -f -- '$@'
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	sed \
		-e 's/__PACKAGE__/$(PACKAGE)/g' \
		-e 's/__VERSION__/$(VERSION)/g' \
		-e 's/__RELEASE__/$(RELEASE)/g' \
		'$<' > '$@' || rm -f -- '$@'
	chmod -w -- '$@'

.PHONY: all install clean distclean
