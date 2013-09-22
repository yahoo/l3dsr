# When making "install" target, libdir must be set by rpmbuild.

CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod
CPPFLAGS = $(addprefix -I,$(INCPATH))
LINK.so  = $(LINK.o) -shared

vpath %.h $(INCPATH)

xt_libdir = $(libdir)/xtables

xtplugins = libxt_DADDR.so

instxtplugins = $(addprefix $(xt_libdir)/,$(xtplugins))

all_targets     = $(xtplugins)
install_targets = $(instxtplugins)
clean_targets   = $(all_targets)


all: $(all_targets)

install: $(install_targets)

clean:
	rm -rf -- $($@_files)

lib%.so: lib%.o
	$(LINK.so) $(OUTPUT_OPTION) $^

lib%.o: lib%.c %.h
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(xt_libdir)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'


.PHONY: all install clean
