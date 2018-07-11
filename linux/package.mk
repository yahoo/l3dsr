package = iptables-daddr
version = 0.8.0

pkg_vers       = $(package)-$(version)
srctardestdir  = $(pkg_vers)
srctarfile     = $(pkg_vers).tar
zsrctarfile    = $(srctarfile).bz2

sinclude package-local.mk
