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
#   ENVBUILD_MKFILE
#   TARBALL_MKFILE
#   PACKAGE_$(os)
#   PKGNAME_$(os)
#   VERSION_$(os)
#   RELEASE_$(os)
#   DIST_$(os)
#   SPECFILE_$(os)
#   RELEASE_BUILD_DATE_$(os)
#   PKGARCH_$(arch)
#   PACKAGE_SUB_EXTRA_VARS
#   PACKAGE_BUILDENV_EXTRA_VARS
#   PACKAGE_vars
#   PACKAGE_vars_os
#   PACKAGE_vars_arch
#

include mk/macros.mk

Package		 = dsrtools
Version		 = 1.0
Release		 = 20150312
Dist		 =
Subdirs		 = src t

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
  $(foreach o,$(OSES),\
    DIST_$o      := $$(if $(Dist_$o),$(Dist_$o),$(Dist))$(nl)\
    RELEASE_$o   := $$(if $(Release_$o),$(Release_$o),$(Release))$(nl)\
    VERSION_$o   := $$(if $(Version_$o),$(Version_$o),$(Version))$(nl)\
    PACKAGE_$o	 := $$(if $(Package_$o),$(Package_$o),$(Package))$(nl)\
    PKGNAME_$o   := $$(if $(Pkgname_$o),$(Pkgname_$o),$$(PACKAGE_$o)-$$(VERSION_$o)-$$(RELEASE_$o))$(nl)\
    SPECFILE_$o  := $$(if $(Specfile_$o),$(Specfile_$o),$$(PACKAGE_$o).spec)$(nl)\
    RELEASE_BUILD_DATE_$o := $$(if $(Release_Build_Date_$o),$(Release_Build_Date_$o),$$(if $(Release_Build_Date),$(Release_Build_Date),$$(if $(RELEASE_BUILD_DATE),$(RELEASE_BUILD_DATE),$(Todays_Date))))$(nl)\
  )\
)

SUBDIRS		?= $(Subdirs)
ENVBUILD_MKFILE ?= mk/Makefile.build
TARBALL_MKFILE  ?= mk/Makefile.tarball

PACKAGE_SUB_EXTRA_VARS +=	\
	SUBDIRS			\
	TARBALL_MKFILE		\
	RELEASE_BUILD_DATE

PACKAGE_vars +=		\
	SUBDIRS			\
	ENVBUILD_MKFILE		\
	TARBALL_MKFILE

PACKAGE_vars_os +=		\
	PACKAGE			\
	PKGNAME			\
	VERSION			\
	RELEASE			\
	DIST			\
	SPECFILE		\
	RELEASE_BUILD_DATE

PACKAGE_vars_arch +=		\
	PKGARCH

PACKAGE_vars_osarch +=
