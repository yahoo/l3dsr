#
# Sourced by Makefiles for setting default macro definitions for rpm builds.
#
# Rarely set optional macros used by spec file:
#   PACKAGE		name of package
#   RELEASE		release of package
#   BUILD_NUMBER	build number of package
#   OSMACRO		see below
#   OSMACROVER		see below
#   KVARIANTS		kernel variants to build (e.g. xen)
#   KVERREL		kernel version and release (e.g. 3.10.0-123.el7)
#   KMODTOOL_LIST	list of kmodtool.* scripts to include
#   URL			URL included in package's information
#   EXTRA_BUILD_DEFS	additional build defs
#
#  For OSMACRO and OSMACROVER these are distribution flavor and code
#  borrowed from Open Build Service:
#  https://en.opensuse.org/openSUSE:Build_Service_cross_distribution_howto
#

specfile   = $(package).spec

extrasrcfiles = \
	kmodtool.el5 \
	kmodtool.el6

rpmtarfile  = $(srctarfile)
zrpmtarfile = $(rpmtarfile).bz2

build_defs = \
	     $(if $(dist),--define 'dist $(dist)') \
	     $(if $(PACKAGE),--define 'kmod_name $(PACKAGE)') \
	     $(if $(VERSION),--define 'kmod_driver_version $(VERSION)') \
	     $(if $(RELEASE),--define 'kmod_rpm_release $(RELEASE)') \
	     $(if $(BUILD_NUMBER),--define 'build_number $(BUILD_NUMBER)') \
	     $(if $(OSMACRO),--define '$(OSMACRO) $(OSMACROVER)') \
	     $(if $(KVARIANTS),--define 'kvariants $(subst ",\",$(KVARIANTS))') \
	     $(if $(KVERREL),--define 'kmod_kernel_version $(KVERREL)') \
	     $(if $(KMODTOOL_LIST),--define 'kmodtool_list $(KMODTOOL_LIST)') \
	     $(if $(URL),--define 'url $(URL)') \
	     $(EXTRA_BUILD_DEFS)
