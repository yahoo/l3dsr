#
# Make a package's RPMs.
#

include mk/macros.mk package.mk


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

BUILDROOT          ?= $(PWD)
BUILDRUNCMD         = $(BUILDROOT)/runbuildenv

$(eval \
  $(foreach o,$(OSES),\
    TARBALLFILE_$o     ?= $(PACKAGE_$o)-$(VERSION_$o).tar.bz2$(nl)\
    TARBALLBUILDDIR_$o ?= build-$o-tarball$(nl)\
    SRCBUILDDIR_$o     ?= build-$o-src$(nl)\
    $(foreach a,$(ARCHES),\
      BINBUILDDIR_$o.$a ?= build-$o-$a$(nl)))\
)

MAKE_vars =			\
	BUILDROOT		\
	BUILDRUNCMD		\
	$(PACKAGE_vars)

MAKE_vars_os =			\
	OSMACRO			\
	OSMACROVER		\
	OSDIST			\
	TARBALLFILE		\
	TARBALLBUILDDIR		\
	SRCBUILDDIR		\
	$(PACKAGE_vars_os)

MAKE_vars_arch =		\
	$(PACKAGE_vars_arch)

MAKE_vars_osarch =		\
	BINBUILDDIR		\
	$(PACKAGE_vars_osarch)

createenv_cookie = .createenv-cookie
prepenv_cookie   = .prepenv-cookie

clean_files     = $(prepenv_cookie)
clobber_files   = $(clean_files) $(createenv_cookie)
distclean_files = $(clobber_files)

os    = $(basename $(1))
arch  = $(patsubst .%,%,$(suffix $(1)))

mkargs_os_call     = $(call mkargs2_call,_$(call os,$(1)),$(2))
mkargs_arch_call   = $(call mkargs2_call,_$(call arch,$(1)),$(2))
mkargs_osarch_call = $(call mkargs2_call,_$(1),$(2))

mkmkargs_call = \
	$(call mkargs_call,$(filter $(MAKE_vars),$(2))) \
	$(call mkargs_os_call,$(1),$(filter $(MAKE_vars_os),$(2))) \
	$(call mkargs_arch_call,$(1),$(filter $(MAKE_vars_arch),$(2))) \
	$(call mkargs_osarch_call,$(1),$(filter $(MAKE_vars_osarch),$(2)))

envbuild_mkvars = \
	PKGARCH \
	OSMACRO OSMACROVER OSDIST \
	PACKAGE_ENVBUILD_EXTRA_VARS \
	$(PACKAGE_ENVBUILD_EXTRA_VARS) \
	BUILDRUNCMD

do_envbuild_mk = \
	$(foreach p,$(PLATFORMS),\
	  $(MAKE) -f '$(ENVBUILD_MKFILE)' \
	    $(call mkmkargs_call,$p,$(envbuild_mkvars)) \
	    $(1)$(nl)\
	)

sub_mkvars = \
	PACKAGE PKGNAME \
	VERSION RELEASE DIST \
	SPECFILE PKGARCH KVARIANTS \
	OSMACRO OSMACROVER \
	TARBALLBUILDDIR TARBALLFILE \
	BUILDROOT SRCBUILDDIR BINBUILDDIR \
	PACKAGE_SUB_EXTRA_VARS \
	$(PACKAGE_SUB_EXTRA_VARS)

do_submks = \
	$(foreach p,$(PLATFORMS),\
	  [ ! -x '$(BUILDRUNCMD)' ] || \
	    $(BUILDRUNCMD) '$(ROOT_$p)' \
	      $(call shdq_call,\
	        $(MAKE) \
		  -C '$(BUILDROOT)' \
		  -f mk/Makefile.sub \
		  $(call mkmkargs_call,$p,$(sub_mkvars)) \
		  $(1))$(nl)\
	)

all tarballs srpms rpms: $(prepenv_cookie)
	+$(call do_submks,$(patsubst %s,%,$@))

create_buildenvs: $(createenv_cookie)

prep_buildenvs: $(prepenv_cookie)

$(prepenv_cookie): $(createenv_cookie)
	+$(call do_envbuild_mk,prep_buildenv)
	@touch -- '$@'

$(createenv_cookie):
	+$(call do_envbuild_mk,create_buildenv)
	@touch -- '$@'

clean clobber distclean::
	+$(call do_submks,$@)
	+$(call do_envbuild_mk,$@)

clean clobber distclean::
	$(call scrub_files_cmd_call,$($@_files))


.PHONY: all tarballs rpms srpms create_buildenvs prep_buildenvs clean clobber distclean
