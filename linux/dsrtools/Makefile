#
# Main makefile for building dsrtools and its packages.
#
#  To build the source:
#    $ make
#
#  To build the packages, specify the package platform with the "spkg" or
#  "pkgs" targets as given in "PPS".  For example:
#    $ make rpm-pkgs
#
#  See INSTALL for further examples.
#

include macros.mk package.mk

MAKEFLAGS += -I..

PPS += rpm mock

$(eval \
  $(foreach pp,$(PPS),\
    $(pp)-%: PP=$(pp)$(nl)\
    $(pp)-%: %;$(nl))\
)

all:
	$(MAKE) -C src

install:
	$(MAKE) -C src $@

tar:
	$(MAKE) -C $@

spkg pkgs print_spkg print_pkgs:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)

clean clobber distclean:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)
	$(if $(PP),,$(MAKE) -C src clean)


.PHONY: all install tar spkg pkgs print_spkg print_pkgs clean clobber distclean
.DELETE_ON_ERROR:
