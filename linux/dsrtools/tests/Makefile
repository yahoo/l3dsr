include ../macros.mk

alltests      = $(sort $(wildcard *.d))
alltestnames  = $(basename $(alltests))
alltesttypes  = $(basename $(alltestnames))
alltrun       = $(patsubst %.sh,%,$(wildcard $(addsuffix /trun.sh,$(alltests))))
myid         := $(shell id -u)

KMOD          = xt_DADDR

DSRCTL       ?= ../../src/dsrctl
VERBOSEARG    = $(if $(V),-v)
REPLACEARG    = $(if $(REPLACE),-r)
KEEPARG       = $(if $(KEEP),-k)
ERRIGNARG     = $(if $(ERRIGN),-i)
ALLARGS       = $(strip $(VERBOSEARG) $(REPLACEARG) $(KEEPARG) $(ERRIGNARG))


# Determine if the xt_DADDR.ko supports the use of any table.
# The modinfo works whether the module is loaded or not.
TableList=mangle
SupportAnyTable=0
ifneq ($(strip $(shell modinfo --field parm xt_DADDR 2>/dev/null)),)
  TableList += raw
  SupportAnyTable=1
endif

testall=$(foreach tbl,$(TableList),$(foreach tst,$(alltests),$(tbl)-$(tst)))


all test: rootcheck runtest $(alltrun) $(testall)

rootcheck:
	@[ $(myid) = "0" ] || { echo "Must be root to run tests."; false; }

%: %.sh
	cp -fp -- '$<' '$@'
	chmod -w+x -- '$@'


mangle-%:
	cd '$*' && DSRCTL='$(DSRCTL)' Tname='$*' ../runtest -t mangle $(ALLARGS)

raw-%:
	cd '$*' && DSRCTL='$(DSRCTL)' Tname='$*' ../runtest -t raw $(ALLARGS)

clean_targets = runtest $(alltrun)
clobber_targets = $(clean_targets)
distclean_targets = $(clobber_targets)

clean clobber distclean:
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)

.PHONY: all clean clobber distclean force rootcheck test
