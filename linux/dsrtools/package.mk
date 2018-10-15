package = dsrtools
version = 1.2.2

pkg_vers       = $(package)-$(version)
srctardestdir  = $(pkg_vers)
srctarfile     = $(pkg_vers).tar
zsrctarfile    = $(srctarfile).xz

sinclude package-local.mk
