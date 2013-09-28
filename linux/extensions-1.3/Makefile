# When making "install" target, libdir must be set by rpmbuild.

CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod-xt-older
CPPFLAGS = $(addprefix -I,$(INCPATH)) -DIPTABLES_VERSION=\"1.3.5\"
LINK.so  = $(LINK.o) -shared

vpath %.h $(INCPATH)

ipt_libdir = $(libdir)/iptables

iptplugins = libipt_DADDR.so libip6t_DADDR.so

instiptplugins = $(addprefix $(ipt_libdir)/,$(iptplugins))

all_targets     = $(iptplugins)
install_targets = $(instiptplugins)
clean_targets   = $(all_targets)


all: $(all_targets)

install: $(install_targets)

clean:
	rm -rf -- $($@_files)

lib%.so: lib%.o
	$(LINK.so) $(OUTPUT_OPTION) $^

lib%.o: lib%.c %.h
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(ipt_libdir)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'


.PHONY: all install clean
