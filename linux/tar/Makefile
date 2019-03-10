#
# Makes the source tarball.
#

include ../macros.mk ../package.mk

subdirs = \
	extensions-1.4 \
	kmod-xt

include $(addsuffix /files.mk,$(addprefix ../,$(subdirs)))

srcfiles += \
	LICENSE \
	README \
	INSTALL \
	USING \
	Makefile \
	macros.mk \
	package.mk

clean_files     = $(zsrctarfile)
clobber_files   = $(clean_files)
distclean_files = $(clobber_files)


all: tar

tar: $(zsrctarfile)

$(zsrctarfile): $(addprefix ../,$(srcfiles)) $(MAKEFILE_LIST)
	tar -cJf '$@' -C .. --transform='s:^:$(srctardestdir)/:' $(srcfiles)

clean clobber distclean:
	$(call scrub_files_call,$($@_files))

.PHONY: all tar clean clobber distclean
.DELETE_ON_ERROR:
