# May be passed in to override defaults:
#   OSES
#   PLATFORMS
#   RELEASE_BUILD_DATE
#
# Sets (directly or indirectly) for Makefile's use:
#   OSES
#   ARCHES
#   PLATFORMS
#   ENVBUILD_MKFILE
#   TARBALL_MKFILE
#   PACKAGE_$(os)
#   PKGNAME_$(os)
#   VERSION_$(os)
#   RELEASE_$(os)
#   DIST_$(os)
#   SPECFILE_$(os)
#   KMODTOOL_$(os)
#   KMODDIR_$(os)
#   KVERREL_$(os)
#   EXTENSIONSDIR_$(os)
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
Version		 = 0.6.2
Release		 = 20130818
Dist		 =
ExtensionsDir	 = extensions-1.4
KmodDir		 = kmod-xt
Kmodtool	 =

Todays_Date := $(shell date '+%Y%m%d')

ifeq ($(NATIVE),)
include $(wildcard package-*.mk)
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
    KMODTOOL_$o  := $$(if $(Kmodtool_$o),$(Kmodtool_$o),$(Kmodtool))$(nl)\
    KMODDIR_$o   := $$(if $(KmodDir_$o),$(KmodDir_$o),$(KmodDir))$(nl)\
    KVERREL_$o   := $$(or $(Kverrel_$o))$(nl)\
    EXTENSIONSDIR_$o      := $$(if $(ExtensionsDir_$o),$(ExtensionsDir_$o),$(ExtensionsDir))$(nl)\
    RELEASE_BUILD_DATE_$o := $$(if $(Release_Build_Date_$o),$(Release_Build_Date_$o),$$(if $(Release_Build_Date),$(Release_Build_Date),$$(if $(RELEASE_BUILD_DATE),$(RELEASE_BUILD_DATE),$(Todays_Date))))$(nl)\
  )\
)

ENVBUILD_MKFILE ?= mk/Makefile.build
TARBALL_MKFILE  ?= mk/Makefile.tarball

PACKAGE_SUB_EXTRA_VARS +=	\
	TARBALL_MKFILE		\
	KMODTOOL		\
	KMODDIR			\
	KVERREL			\
	EXTENSIONSDIR		\
	RELEASE_BUILD_DATE

PACKAGE_vars += 		\
	ENVBUILD_MKFILE		\
	TARBALL_MKFILE

PACKAGE_vars_os += 		\
	PACKAGE			\
	PKGNAME			\
	VERSION			\
	RELEASE			\
	DIST			\
	SPECFILE		\
	KMODTOOL		\
	KMODDIR			\
	KVERREL			\
	EXTENSIONSDIR		\
	RELEASE_BUILD_DATE	\
	SPECFILE

PACKAGE_vars_arch += 		\
	PKGARCH

PACKAGE_vars_osarch += 		\
	KVARIANTS
