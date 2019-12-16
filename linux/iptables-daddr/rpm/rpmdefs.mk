#
# Sourced by Makefiles for setting default macro definitions for rpm builds.
#
# Rarely set optional macros used by spec file:
#   PACKAGE		name of package
#   RELEASE		release of package
#   BUILD_ID		build id, appended to release
#   OSMACRO		see below
#   OSMACROVER		see below
#   KVARIANTS		kernel variants to build (e.g. xen)
#   KVERREL		kernel version and release (e.g. 3.10.0-123.el7)
#   WITHOUT_KMOD	build without kmod package
#   WITH_MANGLE		build kmod package to default to mangle table
#   WITH_OVERRIDE	build kmod package without override file
#   URL			URL included in package's information
#   EXTRA_BUILD_DEFS	additional build defs
#
#  For OSMACRO and OSMACROVER these are distribution flavor and code
#  borrowed from Open Build Service:
#  https://en.opensuse.org/openSUSE:Build_Service_cross_distribution_howto
#

specfile   = $(package).spec

extrasrcfiles = \
	$(package).files

rpmtarfile  = $(srctarfile)
zrpmtarfile = $(rpmtarfile).xz

build_defs = \
	     $(if $(dist),--define 'dist $(dist)') \
	     $(if $(PACKAGE),--define 'kmod_name $(PACKAGE)') \
	     $(if $(VERSION),--define 'kmod_driver_version $(VERSION)') \
	     $(if $(RELEASE),--define 'kmod_rpm_release $(RELEASE)') \
	     $(if $(BUILD_ID),--define 'build_id $(BUILD_ID)') \
	     $(if $(OSMACRO),--define '$(OSMACRO) $(OSMACROVER)') \
	     $(if $(KVARIANTS),--define 'kvariants $(subst ",\",$(KVARIANTS))') \
	     $(if $(KVERREL),--define 'kmod_kernel_version $(KVERREL)') \
	     $(if $(WITHOUT_KMOD),--define '_without_kmod 1') \
	     $(if $(WITH_MANGLE),--define '_with_mangle 1') \
	     $(if $(WITH_OVERRIDE),--define '_with_override 1') \
	     $(if $(URL),--define 'url $(URL)') \
	     $(EXTRA_BUILD_DEFS)
