# When making "install" target, libdir must be set by rpmbuild.

include ../mk/macros.mk ../package.mk

CFLAGS   = -O2 -g -Wall -Wunused -fPIC
INCPATH  = ../kmod
CPPFLAGS = $(addprefix -I,$(INCPATH)) -DIPTABLES_VERSION=\"1.4.7\"
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
	$(call scrub_files_cmd_call,$($@_files))

lib%.so: lib%.o
	$(LINK.so) $(OUTPUT_OPTION) $^

lib%.o: lib%.c %.h
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(xt_libdir)/%: %
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'


.PHONY: all install clean
