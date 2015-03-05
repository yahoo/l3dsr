# For package.mk's use, sets:
#   OSES
#   ARCHES
#   PLATFORMS
#   ENVBUILD_MKFILE
#
# Also sets for overrides:
#   RELEASE_BUILD_DATE_$(os)
#   Dist_$(os)
#   ExtensionsDir_$(os)
#   Kverrel_$(os)
#   Kmodtool_$(os)
#   KmodDir_$(os)
#   KVARIANTS_$p
#
# Also sets for other uses:
#   ROOTIMG_$(os)
#   ROOT_$p
#   PACKAGE_ENVBUILD_EXTRA_VARS


ROOTIMG_rhel4     ?= 4.9-20110216
ROOTIMG_rhel5     ?= 5.8-20120221
ROOTIMG_rhel6     ?= 6.4-20130325

ENVBUILD_MKFILE    = mk/Makefile.ybuild

all_platforms	= rhel4.x86_64 rhel4.i686 \
		  rhel5.x86_64 rhel5.i686 \
		  rhel6.x86_64


ifeq ($(PLATFORMS),)
  ifeq ($(OSES),)
    PLATFORMS := $(all_platforms)
    OSES      := $(sort $(basename $(PLATFORMS)))
  else
    all_oses = $(sort $(basename $(all_platforms)))
    illegal_oses = $(filter-out $(all_oses),$(OSES))
    ifneq ($(illegal_oses),)
      $(error Unexpected value(s) in OSES detected: $(illegal_oses))
    endif
    PLATFORMS := $(filter $(addsuffix .%,$(OSES)),$(all_platforms))
  endif
else
  illegal_platforms = $(filter-out $(all_platforms),$(PLATFORMS))
  ifneq ($(illegal_platforms),)
    $(error Unexpected value(s) in PLATFORMS detected: $(illegal_platforms))
  endif
  OSES := $(sort $(basename $(PLATFORMS)))
endif

ARCHES := $(sort $(patsubst .%,%,$(suffix $(PLATFORMS))))

URL = http://twiki.corp.yahoo.com/view/Platform/Iptables-daddr

OSMACRO_rhel4       = rhel_version
OSMACROVER_rhel4    = 406
OSDIST_rhel4        = .EL

OSMACRO_rhel5       = rhel_version
OSMACROVER_rhel5    = 505
OSDIST_rhel5        = .el5

OSMACRO_rhel6       = rhel_version
OSMACROVER_rhel6    = 600
OSDIST_rhel6        = .el6

OSMACRO_fc17        = fedora
OSMACROVER_fc17     = 17
OSDIST_fc17         = .fc17

KVARIANTS_rhel4.x86_64   ?= "" smp largesmp xenU
KVARIANTS_rhel4.i686     ?= "" smp hugemem xenU
KVARIANTS_rhel5.x86_64   ?= "" xen
KVARIANTS_rhel5.i686     ?= "" xen PAE
KVARIANTS_rhel6.x86_64   ?= ""
KVARIANTS_rhel6.i686     ?= ""   
KVARIANTS_fc17.x86_64    ?= ""
KVARIANTS_fc17.i686      ?= ""

Dist_rhel4      = .EL
Dist_rhel5      = .el5
Dist_rhel6      = .el6
Dist_fc17       = .fc17

Kverrel_rhel4   = 2.6.9-78.EL
Kverrel_rhel5   = 2.6.18-53.el5
Kverrel_rhel6   = 2.6.32-71.el6
Kverrel_fc17    = 2.6.32-71.fc17

$(eval \
  $(foreach o,$(OSES),\
    $(foreach a,$(ARCHES),\
      ROOT_$o.$a ?= \
        $(Package)-build-$o$(subst i686,i386,$(if \
	  $(filter-out x86_64,$a),-$a)$(nl))))\
)


PACKAGE_ENVBUILD_EXTRA_VARS +=		\
	OSDIST				\
	ROOT				\
	ROOTIMG				\
	KVARIANTS			\
	KVERREL				\
	URL

PACKAGE_vars_os +=			\
	OSDIST				\
	ROOTIMG

PACKAGE_vars_osarch +=			\
	ROOT
