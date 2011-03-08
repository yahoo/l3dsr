# Give "N=1" argument to make if you want a native-only build.

.PHONY: all install distclean mkfiles hdrfiles cfiles kofiles installfile \
	instkofiles instinstallfile clean modules_install modules

define nl


endef

PACKAGE  = iptables-daddr
MACHINE := $(shell uname -m)
PWD     := $(shell pwd)
SUBARCH := $(shell uname -m | sed -e s/i.86/i386/)
ARCH    ?= $(SUBARCH)
KERNBASE = 2.6.18-53.el5

INSTDIR  = $(prefix)/lib/modules/yahoo/$(PACKAGE)

ifeq ($(SUBARCH),i386)
extrakver = PAE
else
extrakver =
endif

ifdef N
  ifeq ("$(origin N)", "command line")
    subdirs := $(shell uname -r)
  endif
else
  subdirs = $(KERNBASE) $(addprefix $(KERNBASE), $(extrakver))
endif

installfile = Install
kofiles = $(addsuffix /ipt_DADDR.ko,$(subdirs))

mkfiles = $(addsuffix /Makefile,$(subdirs))
hdrfiles = $(addsuffix /ipt_DADDR.h,$(subdirs))
cfiles = $(addsuffix /ipt_DADDR.c,$(subdirs))

instkofiles = $(addprefix $(INSTDIR)/,$(kofiles))
instinstallfile = $(INSTDIR)/$(installfile)

all_targets = $(kofiles) $(installfile)
install_targets = $(instkofiles) $(instinstallfile)
clean_targets = $(all_targets)
distclean_targets = $(clean_targets) $(subdirs)

all: $(all_targets)

install: $(install_targets)

clean distclean::
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)

clean::
	$(foreach mkfile,\
		$(wildcard $(addsuffix /Makefile,$(subdirs))),\
		$(MAKE) -C '/lib/modules/$(dir mkfile)/build' M='$(PWD)/$(dir mkfile)' $@\
		$(nl)\
	)

$(mkfiles): Makefile.kmod
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	ln -s -- '../$<' '$@'

$(hdrfiles): ipt_DADDR.h
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	ln -s -- '../$<' '$@'

$(cfiles): ipt_DADDR.c
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	ln -s -- '../$<' '$@'

%/ipt_DADDR.ko: %/Makefile %/ipt_DADDR.h %/ipt_DADDR.c
	@echo '$@' '$*' '$<'
	$(MAKE) -C '/lib/modules/$(notdir $(@D))/build' M='$(PWD)/$(notdir $(@D))'

$(INSTDIR)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'

%: %.sed
	rm -f -- '$@'
	sed \
		-e 's:__PREFIX__:$(PACKAGE)/$(KERNBASE):g' \
		'$<' > '$@' || rm -f -- '$@'
	chmod -w -- '$@'

.PRECIOUS: $(hdrfiles) $(cfiles) $(mkfiles)
