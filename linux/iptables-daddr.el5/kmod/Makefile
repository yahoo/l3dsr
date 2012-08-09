# When called from the spec file, it should be invoked with 'KVERREL'
# and 'KVARIANTS'.  'RPM_BUILD_ROOT' and 'RPM_ARCH' will be set
# automatically.
#
# Use /bin/uname for chroot environments.
#
# If you want a native-only build for development, do:
#   $ make KVERREL=`/bin/uname -r` KVARIANTS='""'

include ../mk/macros.mk ../package.mk

$(call varchklist_call,KVERREL KVARIANTS)

INSTDIR   = $(prefix)/lib/modules

ifeq ($(RPM_ARCH),)
  PKGARCH := $(shell /bin/uname -m | sed -e s/i.86/i686/)
else
  PKGARCH := $(shell echo $(RPM_ARCH) | sed -e s/i.86/i686/)
endif

# ARCH is used by the kernel's Makefile.
ARCH := $(shell echo $(PKGARCH) | sed -e s/i.86/i386/)

ifneq ($(RPM_BUILD_ROOT),)
  prefix    = $(RPM_BUILD_ROOT)
endif

# The double-quotes are a marker to mean the straight kernel version.
# Unfortunately, inherited from kmodtool's SOP.
ifneq ($(findstring "",$(KVARIANTS)),)
  subdirs = $(KVERREL)/extra/$(PACKAGE)
endif
subdirs += $(addsuffix /extra/$(PACKAGE), \
		$(addprefix $(KVERREL),$(subst "",,$(KVARIANTS))))

kofiles  = $(addsuffix /xt_DADDR.ko,$(subdirs))
mkfiles  = $(addsuffix /Makefile,$(subdirs))
hdrfiles = xt_DADDR.h
cfiles   = $(addsuffix /xt_DADDR.c,$(subdirs))
lnfiles  = $(mkfiles) $(cfiles)

instkofiles = $(addprefix $(INSTDIR)/,$(kofiles))

all_targets     = $(kofiles)
install_targets = $(instkofiles)
clean_targets   = $(all_targets)

kpath_call = /usr/src/kernels/$(subst --,-,$(subst $(KVERREL),$(KVERREL)-,$(1))-$(PKGARCH))

all: $(all_targets)

install: $(install_targets)

clean::
	$(foreach mkfile,\
		$(wildcard $(mkfiles)),\
		$(MAKE) -C '$(call kpath_call,$(dir $(mkfile)))' M='$(PWD)/$(dir $(mkfile))' $@\
		$(nl)\
	)

clean::
	$(call scrub_files_cmd_call,$($@_files))

$(mkfiles): %:
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	ln -s -- '../../../Makefile.kmod' '$@'

$(cfiles): %:
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	ln -s -- '../../../$(@F)' '$@'

$(kofiles): %: $(lnfiles) $(hdrfiles)
	$(MAKE) -C '$(call kpath_call,$(firstword $(subst /, ,$(@D))))' M='$(PWD)/$(@D)'
	chmod u+x -- '$@'

$(INSTDIR)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'


.PHONY: all install clean
