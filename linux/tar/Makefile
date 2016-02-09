#
# Makes the source tarball.
#

include macros.mk package.mk

subdirs = \
	extensions-1.2 \
	extensions-1.3 \
	extensions-1.4 \
	kmod-ipt \
	kmod-xt-older \
	kmod-xt

include $(addsuffix /files.mk,$(subdirs))

srcfiles += \
	LICENSE \
	README \
	INSTALL \
	USING \
	Makefile \
	macros.mk \
	package.mk

tardestdir = $(pkg_vers)

sources_cookie  = .sources-cookie

clean_files     = $(zsrctarfile) $(sources_cookie)
clobber_files   = $(clean_files) $(tardestdir)
distclean_files = $(clobber_files) 


all: tar

tar: $(zsrctarfile)

# Would use tar --transform, but older tar utils can't handle it.
$(zsrctarfile): $(sources_cookie)
	tar -cjf '$@' '$(tardestdir)'

$(sources_cookie): $(addprefix ../,$(srcfiles)) $(MAKEFILE_LIST)
	$(call scrub_files_call,$(tardestdir))
	mkdir -p -- '$(tardestdir)'
	tar -c -C .. $(srcfiles) | tar -x -C '$(tardestdir)'
	@touch -- '$(sources_cookie)'

clean clobber distclean::
	$(call scrub_files_call,$($@_files))

.PHONY: all tar clean clobber distclean
.DELETE_ON_ERROR:
