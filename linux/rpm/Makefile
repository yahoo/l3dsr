#
# Makes the SRPM and RPM packages.
#
# Optionally takes:
#   TOPDIR			top directory for rpmbuild
#   DIST			%{dist} for rpmbuild or '""' for unsetting it
#   EXTRA_RPMBUILD_ARGS		extra arguments to add to rpmbuild commands
#
# Also see rpmdefs.mk for rarely set optional macros.
#

include macros.mk package.mk rpmdefs.mk

ifdef TOPDIR
  topdir = $(TOPDIR)
else
  topdir := $(shell rpm -E '%{_topdir}')
  ifeq ($(topdir),%{_topdir})
    $(error Cannot determine topdir)
  endif
endif

ifdef DIST
  ifeq ($(DIST),"")
    dist = %{nil}
  else
    dist = $(DIST)
  endif
endif

srpm = $(lastword $(wildcard $(topdir)/SRPMS/$(package)-$(version)-*.src.rpm))
rpms = $(wildcard $(topdir)/RPMS/*/*$(package)-*$(version)-*.rpm)

tardir = ../tar

spkg_cookie = .spkg-cookie
pkgs_cookie = .pkgs-cookie

rpmbuild_defs   = $(build_defs) \
		  $(if $(TOPDIR),--define '_topdir $(TOPDIR)')

rpmbuild_args   = $(rpmbuild_defs) \
		  $(EXTRA_RPMBUILD_ARGS)

clean_files     = $(zrpmtarfile) $(rpmtarfile) \
		  $(spkg_cookie) $(pkgs_cookie)
clobber_files   = $(clean_files) $(srpm) $(rpms)
distclean_files = $(clobber_files)


all: spkg pkgs

spkg: $(spkg_cookie)

pkgs: $(pkgs_cookie)

zrpmtar: $(zrpmtarfile)

$(tardir)/$(zsrctarfile):
	$(MAKE) -C '$(@D)' '$(@F)'

$(rpmtarfile): $(tardir)/$(zsrctarfile) $(extrasrcfiles) $(specfile)
	bzip2 -cdk '$<' > '$@'
	tar -rf '$@' $(extrasrcfiles) '$(specfile)'

$(zrpmtarfile): $(rpmtarfile)
	bzip2 -czk '$<' > '$@'

$(spkg_cookie): $(zrpmtarfile)
	rpmbuild -ts $(rpmbuild_args) '$<'
	@touch -- '$@'

$(pkgs_cookie): $(zrpmtarfile)
	rpmbuild -tb $(rpmbuild_args) '$<'
	@touch -- '$@'

clean clobber distclean:
	$(call scrub_files_call,$($@_files))
	$(MAKE) -C '$(tardir)' $@


.PHONY: all spkg pkgs zrpmtar clean clobber distclean
.DELETE_ON_ERROR:
