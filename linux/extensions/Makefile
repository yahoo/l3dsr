.PHONY: all install clean distclean

MACHINE := $(shell uname -m)

define nl


endef

CFLAGS = -O2 -g

ifeq ($(MACHINE),x86_64)
LIBDIR = lib64
else
LIBDIR = lib
endif

ipt_libdir = $(LIBDIR)/iptables

INSTDIR = $(prefix)/$(ipt_libdir)

iptplugin = libipt_DADDR.so

instiptplugin = $(addprefix $(INSTDIR)/,$(iptplugin))

all_targets = $(iptplugin)
install_targets = $(instiptplugin)
clean_targets = $(all_targets)
distclean_targets = $(clean_targets)

all: $(all_targets)

install: $(install_targets)

clean distclean:
	$(foreach file,\
		$(filter $(wildcard $($(@)_targets)),$($(@)_targets)),\
		rm -rf -- '$(file)'\
		$(nl)\
	)

lib%.so: lib%.o
	$(CC) -shared -o $@ $^

# If building in 32-bit mode on a 64-bit kernel, need
# -DIPT_MIN_ALIGN=8 -DKERNEL_64_USERSPACE_32
lib%.o: lib%.c %.h
	$(CC) $(CFLAGS) \
	-Wall -Wunused \
	-DIPTABLES_VERSION=\"1.3.5\" \
	-fPIC -c $<

$(instiptplugin): $(iptplugin)

$(prefix)/%:
	@[ -d '$(@D)' ] || mkdir -p -- '$(@D)'
	cp -fp -- '$<' '$@'
