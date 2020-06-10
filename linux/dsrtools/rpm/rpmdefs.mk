#
# Sourced by Makefiles for setting default macro definitions for rpm builds.
#
# Rarely set optional macros used by spec file:
#   DIST		%{dist} for rpmbuild or '""' for unsetting it
#   PACKAGE		name of package
#   RELEASE		release of package
#   BUILD_ID		build id, appended to release
#   OSMACRO		see below
#   OSMACROVER		see below
#   URL			URL included in package's information
#   EXTRA_BUILD_DEFS	additional build defs
#
#  For OSMACRO and OSMACROVER these are distribution flavor and code
#  borrowed from Open Build Service:
#  https://en.opensuse.org/openSUSE:Build_Service_cross_distribution_howto
#

specfile   = $(package).spec

rpmtarfile  = $(srctarfile)
zrpmtarfile = $(rpmtarfile).xz

build_defs = \
	     $(strip \
	     $(if $(DIST),\
	       --define 'dist $(if $(subst x"",,x$(DIST)),$(DIST),%{nil})') \
	     $(if $(PACKAGE),--define 'pkg_name $(PACKAGE)') \
	     $(if $(VERSION),--define 'pkg_version $(VERSION)') \
	     $(if $(RELEASE),--define 'pkg_release $(RELEASE)') \
	     $(if $(BUILD_ID),--define 'build_id $(BUILD_ID)') \
	     $(if $(OSMACRO),--define '$(OSMACRO) $(OSMACROVER)') \
	     $(if $(URL),--define 'url $(URL)') \
	     $(EXTRA_BUILD_DEFS))
