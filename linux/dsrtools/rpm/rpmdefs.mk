#
# Sourced by Makefiles for setting default macro definitions for rpm builds.
#
# Rarely set optional macros used by spec file:
#   PACKAGE		name of package
#   RELEASE		release of package
#   BUILD_NUMBER	build number of package
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

extrasrcfiles =

rpmtarfile  = $(srctarfile)
zrpmtarfile = $(rpmtarfile).bz2

build_defs = \
	     $(if $(dist),--define 'dist $(dist)') \
	     $(if $(BUILD_NUMBER),--define 'build_number $(BUILD_NUMBER)') \
	     $(if $(OSMACRO),--define '$(OSMACRO) $(OSMACROVER)') \
	     $(if $(URL),--define 'url $(URL)') \
	     $(EXTRA_BUILD_DEFS)
