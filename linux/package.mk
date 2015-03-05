# May be passed in to override defaults:
#   PLATFORMS or OSES and ARCHES
#   RELEASE_BUILD_DATE
#   PKGFILE
#   CONFIG_ARGS
#
# Sets (directly or indirectly) for Makefile's use:
#   OSES
#   ARCHES
#   PLATFORMS
#   SUBDIRS
#   KMODTOOL_LIST
#   ENVBUILD_MKFILE
#   TARBALL_MKFILE
#   PACKAGE_$(os)
#   PKGNAME_$(os)
#   VERSION_$(os)
#   RELEASE_$(os)
#   DIST_$(os)
#   SPECFILE_$(os)
#   KVERREL_$(os)
#   RELEASE_BUILD_DATE_$(os)
#   PKGARCH_$(arch)
#   KVARIANTS_$(os).$(arch)
#   PACKAGE_SUB_EXTRA_VARS
#   PACKAGE_BUILDENV_EXTRA_VARS
#   PACKAGE_vars
#   PACKAGE_vars_os
#   PACKAGE_vars_arch
#   PACKAGE_vars_osarch
#

include mk/macros.mk

Package		 = iptables-daddr
Version		 = 0.7.0
Release		 = 20150304
Dist		 =
Subdirs		 = extensions-1.2 extensions-1.3 extensions-1.4 \
		   kmod-ipt kmod-xt-older kmod-xt
Kmodtool_list	 = kmodtool.el5 kmodtool.el6

Todays_Date := $(shell date '+%Y%m%d')


NATIVEPKGFILE   ?= package-native.mk
PKGFILE         ?= $(filter-out $(NATIVEPKGFILE),$(wildcard package-*.mk))

do_native =
ifneq ($(NATIVE),)
  do_native = 1
endif

ifeq ($(PKGFILE),)
  do_native = 1
endif

ifneq ($(do_native),)
  ifeq ($(wildcard $(NATIVEPKGFILE)),)
    $(shell ./config-native $(CONFIG_ARGS) > $(NATIVEPKGFILE))
  endif
  include $(NATIVEPKGFILE)
else
  include $(PKGFILE)
endif


ifneq ($(PLATFORMS),)
  OSES   := $(sort $(basename $(PLATFORMS)))
  ARCHES := $(sort $(patsubst .%,%,$(suffix $(PLATFORMS))))
else
  ARCHES := $(shell uname -p)
  OSES   ?= native
  PLATFORMS = $(addsuffix .$(ARCHES),$(OSES))
endif

$(eval \
  $(foreach a,$(ARCHES),\
    PKGARCH_$a = $a$(nl))\
)

$(eval \
  $(foreach p,$(PLATFORMS),\
    KVARIANTS_$p ?= ""$(nl)\
  )\
)

$(eval \
  $(foreach o,$(OSES),\
    DIST_$o      := $$(if $(Dist_$o),$(Dist_$o),$(Dist))$(nl)\
    RELEASE_$o   := $$(if $(Release_$o),$(Release_$o),$(Release))$(nl)\
    VERSION_$o   := $$(if $(Version_$o),$(Version_$o),$(Version))$(nl)\
    PACKAGE_$o	 := $$(if $(Package_$o),$(Package_$o),$(Package))$(nl)\
    PKGNAME_$o   := $$(if $(Pkgname_$o),$(Pkgname_$o),$$(PACKAGE_$o)-$$(VERSION_$o)-$$(RELEASE_$o))$(nl)\
    SPECFILE_$o  := $$(if $(Specfile_$o),$(Specfile_$o),$$(PACKAGE_$o).spec)$(nl)\
    KVERREL_$o   := $$(if $(Kverrel_$o),$(Kverrel_$o),)$(nl)\
    RELEASE_BUILD_DATE_$o := $$(if $(Release_Build_Date_$o),$(Release_Build_Date_$o),$$(if $(Release_Build_Date),$(Release_Build_Date),$$(if $(RELEASE_BUILD_DATE),$(RELEASE_BUILD_DATE),$(Todays_Date))))$(nl)\
  )\
)

KMODTOOL_LIST	?= $(Kmodtool_list)
SUBDIRS		?= $(Subdirs)
ENVBUILD_MKFILE ?= mk/Makefile.build
TARBALL_MKFILE  ?= mk/Makefile.tarball

PACKAGE_SUB_EXTRA_VARS +=	\
	KMODTOOL_LIST		\
	SUBDIRS			\
	TARBALL_MKFILE		\
	KVERREL			\
	RELEASE_BUILD_DATE

PACKAGE_vars += 		\
	KMODTOOL_LIST		\
	SUBDIRS			\
	ENVBUILD_MKFILE		\
	TARBALL_MKFILE

PACKAGE_vars_os += 		\
	PACKAGE			\
	PKGNAME			\
	VERSION			\
	RELEASE			\
	DIST			\
	SPECFILE		\
	KVERREL			\
	RELEASE_BUILD_DATE

PACKAGE_vars_arch += 		\
	PKGARCH

PACKAGE_vars_osarch += 		\
	KVARIANTS
