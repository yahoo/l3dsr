# When making "install" target, libdir must be set by rpmbuild.

include ../mk/macros.mk ../package.mk

CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod include
CPPFLAGS = $(addprefix -I,$(INCPATH)) -DIPTABLES_VERSION=\"1.2.11\"
LINK.so  = $(LINK.o) -shared

vpath %.h $(INCPATH)

ipt_libdir = $(libdir)/iptables

iptplugins = libipt_DADDR.so

instiptplugins = $(addprefix $(ipt_libdir)/,$(iptplugins))

all_targets     = $(iptplugins)
install_targets = $(instiptplugins)
clean_targets   = $(all_targets)


all: $(all_targets)

install: $(install_targets)

clean:
	$(call scrub_files_cmd_call,$($@_files))

lib%.so: lib%.o
	$(LINK.so) $(OUTPUT_OPTION) $^

lib%.o: lib%.c %.h
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(ipt_libdir)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'


.PHONY: all install clean
