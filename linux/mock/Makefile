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

include macros.mk package.mk rpm/rpmdefs.mk

MOCK = mock

ifdef DIST
  ifeq ($(DIST),"")
    dist = %{nil}
  else
    dist = $(DIST)
  endif
endif

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

spkg_cookie    = .spkg-cookie
pkgs_cookie    = .pkgs-cookie
sources_cookie = .sources-cookie

srpm = $(lastword $(wildcard $(srpm_resultdir)/$(package)-$(version)-*.src.rpm))
rpms = $(wildcard $(rpm_resultdir)/$(package)-$(version)-*.rpm)

clean_files     = $(sourcesfiles) \
		  $(spkg_cookie) $(pkgs_cookie) $(sources_cookie)
clobber_files   = $(clean_files) $(rpms) $(srpm) $(sources) \
		  $(rpm_resultdir) $(srpm_resultdir)
distclean_files = $(clobber_files)


all: spkg pkgs

spkg: $(spkg_cookie)

pkgs: $(pkgs_cookie)

$(tardir)/$(zsrctarfile):
	$(MAKE) -C '$(@D)' '$(@F)'

$(sources)/$(zsrctarfile): $(tardir)/$(zsrctarfile)
	$(call mkdirs_call,$(@D))
	cp -- '$<' '$@'

$(sources)/%: $(rpmdir)/%
	$(call mkdirs_call,$(@D))
	cp -- '$<' '$@'

$(spkg_cookie): $(sourcesfiles) $(sources)/$(zsrctarfile)
	$(MOCK) \
		--target='noarch' \
		$(mock_srpm_args) \
		--buildsrpm \
		--sources '$(sources)' \
		--spec '$(rpmspecfile)'
	@touch -- '$@'

$(pkgs_cookie): $(spkg_cookie)
	$(MOCK) $(mock_rpm_args) --rebuild '$(srpm)'
	@touch -- '$@'

clean clobber distclean:
	$(call scrub_files_call,$($@_files))
	$(MAKE) -C '$(rpmdir)' '$@'
	$(MAKE) -C '$(tardir)' '$@'


.PHONY: all spkg pkgs clean clobber distclean
.DELETE_ON_ERROR:
