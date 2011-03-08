.PHONY: userdefault all install clean distclean tar srpm rpm

PACKAGE = iptables-daddr
VERSION = 0.2.1
RELEASE = 20110121
DIST	= .el5
PKGNAME = $(PACKAGE)-$(VERSION)-$(RELEASE)$(DIST)
MACHINE := $(shell uname -m)
PWD     := $(shell pwd)

RPMBUILD = rpmbuild --define '_topdir $(topdir)'
SUBDIRS  = extensions kmod

define nl


endef

ifeq ($(topdir),)
topdir := $(PWD)/TOPDIR
endif

ifeq ($(prefix),)
prefix := $(PWD)/BUILDROOT
endif

ifneq ($(shell date '+%Y%m%d'),$(RELEASE))
$(warning WARNING: Today's date does not match the release date!)
endif


include $(addsuffix /Makefile.incl,$(SUBDIRS))

srcfiles += \
	README \
	Makefile \
	iptables-daddr.spec.sed

specfile = $(PACKAGE).spec
tarprefix = $(PKGNAME)
tarfiles = $(srcfiles)

tdbuilddirs = $(addprefix $(topdir)/,BUILD RPMS SPECS SRPMS SOURCES)
tdtarfile   = $(topdir)/SOURCES/$(PKGNAME).tar.bz2
tdspecfile  = $(topdir)/SPECS/$(specfile)
tdrpmfile   = $(topdir)/RPMS/$(MACHINE)/$(PKGNAME).$(MACHINE).rpm
tdsrpmfile  = $(topdir)/SRPMS/$(PKGNAME).src.rpm

clean_targets = $(tarprefix)
distclean_targets = $(clean_targets) $(prefix) $(topdir)

userdefault: srpm rpm

all install clean distclean::
	$(foreach dir,$(SUBDIRS),$(MAKE) -C '$(dir)' prefix='$(prefix)' $@$(nl))

clean distclean::
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)


tar: $(tdtarfile)
srpm: $(tdsrpmfile)
rpm: $(tdrpmfile)

$(tdspecfile): $(specfile).sed
	rm -f -- '$@'
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	sed \
		-e 's/__PACKAGE__/$(PACKAGE)/g' \
		-e 's/__VERSION__/$(VERSION)/g' \
		-e 's/__RELEASE__/$(RELEASE)$(DIST)/g' \
		'$<' > '$@' || rm -f -- '$@'
	chmod -w -- '$@'

$(tdtarfile): $(tarfiles)
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	@[ -h '$(tarprefix)' ] || ln -s -- . '$(tarprefix)'
	tar -cjhf '$@' --exclude .svn $(addprefix $(tarprefix)/,$^)
	@rm -f '$(tarprefix)'

$(tdrpmfile): $(tdspecfile) $(tdtarfile)
	$(foreach dir,\
		$(filter-out $(wildcard $(tdbuilddirs)),$(tdbuilddirs)),\
		mkdir -p -- '$(dir)'$(nl)\
	)
	$(RPMBUILD) -bb $(tdspecfile)

$(tdsrpmfile): $(tdspecfile) $(tdtarfile)
	$(foreach dir,\
		$(filter-out $(wildcard $(tdbuilddirs)),$(tdbuilddirs)),\
		mkdir -p -- '$(dir)'$(nl)\
	)
	$(RPMBUILD) -bs $(tdspecfile)
