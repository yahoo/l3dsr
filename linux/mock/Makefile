#
# Makes the SRPM and RPM packages using mock.
#
# Optionally takes:
#   MOCK			mock (can be useful to set to "sudo mock")
#   DIST			%{dist} for rpmbuild or '""' for unsetting it
#   MOCK_SRPM_RESULTDIR		--resultdir for building SRPM
#   MOCK_RPM_RESULTDIR		--resultdir for building RPMs
#   EXTRA_MOCK_SRPM_ARGS	extra mock arguments when building SRPM
#   EXTRA_MOCK_RPM_ARGS		extra mock arguments when building RPMs
#
# Also see rpm/rpmdefs.mk for rarely set optional macros.
#

ifdef DIST
  ifeq ($(DIST),"")
    dist = %{nil}
  else
    dist = $(DIST)
  endif
endif

include macros.mk package.mk rpm/rpmdefs.mk

MOCK ?= mock

srpm_resultdir = $(or $(MOCK_SRPM_RESULTDIR),results_srpm)
rpm_resultdir  = $(or $(MOCK_RPM_RESULTDIR),results_rpm)

mock_srpm_args  = $(build_defs) \
		  --resultdir='$(srpm_resultdir)' \
		  $(EXTRA_MOCK_SRPM_ARGS)

mock_rpm_args   = $(build_defs) \
		  --resultdir='$(rpm_resultdir)' \
		  $(EXTRA_MOCK_RPM_ARGS)

tardir = ../tar
rpmdir = ../rpm

rpmspecfile  = $(rpmdir)/$(specfile)
sources      = SOURCES
sourcesfiles = $(addprefix $(sources)/,$(extrasrcfiles))

rpmpkgs  := $(shell \
	$(MOCK) $(mock_srpm_args) --quiet \
		--copyin '$(rpmspecfile)' . && \
	$(MOCK) $(mock_srpm_args) --quiet \
		--shell "rpm -q $(build_defs) --specfile '$(specfile)'")
rpmpkgs  := $(rpmpkgs) kmod-$(firstword $(rpmpkgs))
rpms      = $(foreach p,$(rpmpkgs),$(rpm_resultdir)/$p.rpm)

pkgarches = $(foreach p,$(rpmpkgs),$(lastword $(subst ., ,$p)))
srpmpkg   = $(patsubst %.$(firstword $(pkgarches)),%,$(firstword $(rpmpkgs)))
srpm      = $(srpm_resultdir)/$(srpmpkg).src.rpm

clean_files     = $(rpms) $(srpm) $(sourcesfiles)
clobber_files   = $(clean_files) $(sources) $(rpm_resultdir) $(srpm_resultdir)
distclean_files = $(clobber_files)


all: spkg pkgs

spkg: $(srpm)

pkgs: $(rpms)

$(tardir)/$(zsrctarfile):
	$(MAKE) -C '$(@D)' '$(@F)'

$(sources)/$(zsrctarfile): $(tardir)/$(zsrctarfile) | $(sources)
	cp -fp -- '$<' '$@'

$(sources)/%: $(rpmdir)/% | $(sources)
	cp -fp -- '$<' '$@'

$(srpm): $(sourcesfiles) $(sources)/$(zsrctarfile) $(rpmspecfile)
	$(MOCK) \
		$(mock_srpm_args) \
		--buildsrpm \
		--sources '$(sources)' \
		--spec '$(rpmspecfile)'

$(rpms): $(srpm)
	$(MOCK) $(mock_rpm_args) --rebuild '$(srpm)'

$(srpm) $(rpms): $(MAKEFILE_LIST)

$(sources):
	mkdir -p -- '$@'

print_spkg:
	@echo '$(addprefix $(CURDIR)/,$(srpm))'

print_pkgs:
	@echo '$(addprefix $(CURDIR)/,$(rpms))'

clean clobber distclean:
	$(call scrub_files_call,$($@_files))
	$(MAKE) -C '$(rpmdir)' '$@'
	$(MAKE) -C '$(tardir)' '$@'


.PHONY: all spkg pkgs print_spkg print_pkgs clean clobber distclean
.DELETE_ON_ERROR:
