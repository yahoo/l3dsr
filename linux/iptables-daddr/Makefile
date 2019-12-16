#
# Main makefile for building iptables-daddr and its packages.
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

def_kmoddir ?= kmod-xt
def_lmoddir ?= extensions-1.4

uname_r       := $(shell uname -r)
kmod_make_dir  = /lib/modules/$(uname_r)/build
kmod_make_args = -C '$(kmod_make_dir)' M='$(CURDIR)/$(def_kmoddir)'

all:
	$(MAKE) $(kmod_make_args)
	$(MAKE) -C '$(def_lmoddir)'

install:
	$(MAKE) $(kmod_make_args) modules_install
	$(MAKE) -C '$(def_lmoddir)' $@

tar:
	$(MAKE) -C $@

spkg pkgs print_spkg print_pkgs:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)

clean clobber distclean:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)
	$(if $(PP),,$(MAKE) -C '$(def_lmoddir)' clean)
	$(if $(PP),,$(MAKE) $(kmod_make_args) clean)


.PHONY: all install tar spkg pkgs print_spkg print_pkgs clean clobber distclean
.DELETE_ON_ERROR:
