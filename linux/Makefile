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
#  See the README for further examples.
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


all: src

src:
	$(MAKE) -C /lib/modules/`uname -r`/build \
		M='$(PWD)/$(def_kmoddir)'
	$(MAKE) -C '$(def_lmoddir)'

tar:
	$(MAKE) -C $@

spkg pkgs:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)

clean clobber distclean:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)
	$(if $(PP),,$(MAKE) -C '$(def_lmoddir)' clean)
	$(if $(PP),,$(MAKE) -C /lib/modules/`uname -r`/build \
		M='$(PWD)/$(def_kmoddir)' clean)


.PHONY: all src tar spkg pkgs clean clobber distclean
.DELETE_ON_ERROR:
