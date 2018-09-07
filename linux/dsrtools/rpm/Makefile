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

include ../package.mk rpmdefs.mk

ifdef TOPDIR
  topdir = $(TOPDIR)
else
  topdir := $(shell rpm -E '%{_topdir}')
  ifeq ($(topdir),%{_topdir})
    $(error Cannot determine topdir)
  endif
endif

rpmpkgs  := $(shell rpm -q $(build_defs) --specfile '$(specfile)' 2> /dev/null)

pkgarches = $(foreach p,$(rpmpkgs),$(lastword $(subst ., ,$p)))
rpmdirs   = $(foreach a,$(pkgarches),$(topdir)/RPMS/$a/)
rpms      = $(addsuffix .rpm,$(join $(rpmdirs),$(rpmpkgs)))

srpmpkg   = $(patsubst %.$(firstword $(pkgarches)),%,$(firstword $(rpmpkgs)))
srpm      = $(topdir)/SRPMS/$(srpmpkg).src.rpm

tardir = ../tar

rpmbuild_defs   = $(build_defs) \
		  $(if $(TOPDIR),--define '_topdir $(TOPDIR)')

rpmbuild_args   = $(rpmbuild_defs) \
		  $(EXTRA_RPMBUILD_ARGS)

clean_files     = $(rpms) $(srpm) $(zrpmtarfile) $(rpmtarfile)
clobber_files   = $(clean_files) $(TOPDIR)
distclean_files = $(clobber_files)


all: spkg pkgs

spkg: $(srpm)

pkgs: $(rpms)

zrpmtar: $(zrpmtarfile)

$(tardir)/$(zsrctarfile):
	$(MAKE) -C '$(@D)' '$(@F)'

$(rpmtarfile): $(tardir)/$(zsrctarfile) $(extrasrcfiles) $(specfile)
	xz -cdk '$<' > '$@'
	tar -rf '$@' $(extrasrcfiles) '$(specfile)'

$(zrpmtarfile): $(rpmtarfile)
	xz -czk '$<' > '$@'

$(srpm): $(zrpmtarfile)
	rpmbuild -ts --target=noarch $(rpmbuild_args) '$<'

$(rpms): $(zrpmtarfile)
	rpmbuild -tb $(rpmbuild_args) '$<'

$(srpm) $(rpms): $(MAKEFILE_LIST)

print_spkg:
	@echo '$(srpm)'

print_pkgs:
	@echo '$(rpms)'

clean clobber distclean:
	$(RM) -r -- $($@_files)
	$(MAKE) -C '$(tardir)' $@


.PHONY: all spkg pkgs zrpmtar print_spkg print_pkgs clean clobber distclean
.DELETE_ON_ERROR:
