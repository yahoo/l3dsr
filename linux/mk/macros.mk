#
# Include file of common macros for makefiles.
#

define nl


endef

define pound
#
endef

PWD       := $(shell pwd)

tarfile    = $(PACKAGE)-$(VERSION).tar.bz2
specfile   = $(PACKAGE).spec

rpmdirs    = BUILD RPMS SOURCES SPECS SRPMS


varchk_call = $(if $($(1)),,$(error $(1) is not set from calling environment))

varchklist_call = $(foreach v,$(1),$(call varchk_call,$v))

mkargs_call = $(foreach v,$(1),$v='$($v)')

copy_file_cmd_call = \
	[ -d '$(dir $(2))' ] || mkdir -p -- '$(dir $(2))' && \
	cp -a -- '$(1)' '$(2)'$(nl)

scrub_files_cmd_call = $(foreach f,$(wildcard $(1)),rm -rf -- '$f'$(nl))

mkdirs_cmd_call = $(foreach f,$(filter-out $(wildcard $(1)),$(1)),\
		    mkdir -p -- '$f'$(nl))

mkrpmdirs_cmd_call = $(call mkdirs_cmd_call,$(addprefix $(1)/,$(rpmdirs)))
