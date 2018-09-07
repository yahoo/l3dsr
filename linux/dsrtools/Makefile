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

include macros.mk

PPS += rpm mock

$(eval \
  $(foreach pp,$(PPS),\
    $(pp)-%: PP=$(pp)$(nl)\
    $(pp)-%: %;$(nl))\
)

all install:
	$(MAKE) -C src '$@'

tar:
	$(MAKE) -C '$@' all

src-% tar-%:
	$(MAKE) -C '$(subst -$*,,$@)' '$*'

spkg pkgs print_spkg print_pkgs:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)

clean clobber distclean:
	$(if $(PP),$(MAKE) -C '$(PP)' $@)
	$(MAKE) -C tar $@
	$(MAKE) -C src $@


.PHONY: all install tar spkg pkgs print_spkg print_pkgs
.PHONY: clean clobber distclean
.DELETE_ON_ERROR:
