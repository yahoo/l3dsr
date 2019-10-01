CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod-xt
CPPFLAGS = $(addprefix -I,$(INCPATH))
LINK.so  = $(LINK.o) -shared

vpath %.h $(INCPATH)

dflt_ipt_libdir = $(firstword $(wildcard \
		    $(addsuffix /xtables,\
		      $(addprefix $(DESTDIR),\
			/usr/lib64 /lib64 /usr/lib /lib))))

ipt_libdir ?= $(if $(libdir),$(libdir)/xtables,$(dflt_ipt_libdir))

ifeq ($(ipt_libdir),)
  $(error Must set libdir or ipt_libdir)
endif

iptplugin       = libxt_DADDR.so

instiptplugin   = $(ipt_libdir)/$(iptplugin)

all_targets     = $(iptplugin)
install_targets = $(instiptplugin)
clean_targets   = $(all_targets)


all: $(all_targets)

install: $(install_targets)

clean:
	rm -rf -- $($@_targets)

lib%.so: lib%.o
	$(LINK.so) $(OUTPUT_OPTION) $^

lib%.o: lib%.c %.h
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(ipt_libdir)/%: % | $(ipt_libdir)
	cp -fp -- '$<' '$@'

$(ipt_libdir):
	mkdir -p -- '$@'


.PHONY: all install clean
.DELETE_ON_ERROR:
