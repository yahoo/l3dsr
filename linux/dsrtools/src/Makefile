$(call varchklist_call,\
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

instrcfile      = $(INSTDIR)/etc/rc.d/init.d/$(rcfilebase)
instcmdfile     = $(INSTDIR)/usr/sbin/$(cmdfile)
instservicefile = $(INSTDIR)/usr/lib/systemd/system/$(servicefile)
instman5file    = $(INSTDIR)/usr/share/man/man5/$(man5file)
instman8file    = $(INSTDIR)/usr/share/man/man8/$(man8file)

instrcd         = $(INSTDIR)/etc/rc.d/init.d
instconfd       = $(INSTDIR)/etc/$(confdir)
instcmdd        = $(INSTDIR)/usr/sbin
instserviced    = $(INSTDIR)/usr/lib/systemd/system
instman5d       = $(INSTDIR)/usr/share/man/man5
instman8d       = $(INSTDIR)/usr/share/man/man8
instreadme      = $(INSTDIR)/etc/$(confdir)/$(readme)

ifeq ($(WITHSYSTEMD),1)
  rcfile=
  instrcfile=
  instrcd=
else
  servicefile=
  instservicefile=
  instserviced=
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
		  $(instrcd) \
		  $(instcmdd) \
		  $(instconfd) \
		  $(instreadme)

instdirs        = $(instrcd) \
                  $(instconfd) \
                  $(instcmdd) \
                  $(instserviced) \
                  $(instman5d) \
                  $(instman8d)

clean_targets = $(all_targets)

distclean_targets = $(clean_targets) $(topdir)

all: $(all_targets)

install: $(install_targets)

$(instservicefile): $(servicefile) | $(instserviced)
	cp -fp -- '$<' '$@'

$(instrcfile): $(rcfile) $(instrcd)
	cp -fp -- '$<' '$@'

$(instcmdfile): $(cmdfile) | $(instcmdd)
	cp -fp -- '$<' '$@'

$(instman5file): $(man5file) | $(instman5d)
	cp -fp -- '$<' '$@'

$(instman8file): $(man8file) | $(instman8d)
	cp -fp -- '$<' '$@'

$(instreadme): $(readme) | $(instconfd)
	cp -fp -- '$<' '$@'

$(instdirs):
	mkdir -p -- '$@'

clean clobber distclean:
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)

%: %.sh
	cp -fp -- '$<' '$@'
	chmod -w+x -- '$@'

%: %.txt
	cp -fp -- '$<' '$@'
	chmod -w -- '$@'

%: %.sed
	rm -f -- '$@'
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	sed \
		-e 's/__VERSION__/$(VERSION)/g' \
		'$<' > '$@' || rm -f -- '$@'
	chmod -w -- '$@'

.PHONY: all install clean clobber distclean
.DELETE_ON_ERROR:
