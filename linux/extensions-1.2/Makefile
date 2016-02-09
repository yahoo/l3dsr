# When making "install" target, libdir or ipt_libdir must be set.

CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod-ipt include
CPPFLAGS = $(addprefix -I,$(INCPATH)) -DIPTABLES_VERSION=\"1.2.11\"
LINK.so  = $(LINK.o) -shared

vpath %.h $(INCPATH)

ipt_libdir ?= $(libdir)/iptables

iptplugins  = libipt_DADDR.so

instiptplugins = $(addprefix $(ipt_libdir)/,$(iptplugins))

all_targets     = $(iptplugins)
install_targets = $(instiptplugins)
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
