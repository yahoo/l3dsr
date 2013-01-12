changequote({{,}})dnl
%define kmod_name               __PACKAGE__
%define kmod_driver_version     __VERSION__
%define kmod_rpm_release        __RELEASE__
%define kmod_kernel_version     __KVERREL__

Summary: Iptables destination address rewriting for IPv4 and IPv6
Name: %{kmod_name}
Version: %{kmod_driver_version}
Release: %{kmod_rpm_release}%{?dist}
License: GPLv2
Group: Applications/System
ifelse(__URL__,{{}},{{}},{{dnl
URL: __URL__
}})dnl
Vendor: Yahoo! Inc.
Packager: Quentin Barnes <qbarnes@yahoo-inc.com>

BuildRequires: /bin/sed
BuildRequires: iptables-devel >= 1.4.7, iptables-devel < 1.5
Requires: iptables >= 1.4.7, iptables < 1.5
Requires: %{name}-kmod >= %{version}

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%define _prefix %{nil}
%define rpmversion %{version}-%{release}
%define fullpkgname %{name}-%{rpmversion}

Source: %{name}-%{version}.tar.bz2
Source1: kmodtool

%define kmodtool sh %{SOURCE1}

# Create a preinstall and preuninstall scripts as a macro for processing
# with sed that ensures any existing xt_DADDR module, if present, can
# be removed.  If not, fail.
%define pkgko xt_DADDR
%define kmodrm rmmod '%{pkgko}' 2> /dev/null || true;if %__grep -qw '^%{pkgko}' /proc/modules;then echo -e >\\&2 "WARNING: Unable to remove current %{pkgko} module!\\\\nRemove iptables rules using DADDR and try again.";exit 1;fi
%define prekmodrm if [ "$1" -eq 1 ];then %{kmodrm};fi
%define preunkmodrm if [ "$1" -eq 0 ];then %{kmodrm};fi

ifelse(__OSDIST__,{{.EL}},{{dnl
%define kverrel %(%{kmodtool} verrel %{?kmod_kernel_version} 2>/dev/null)
}},__OSDIST__,{{.el5}},{{dnl
%define kverrel %(%{kmodtool} verrel %{?kmod_kernel_version} 2>/dev/null)
}},{{dnl
%define kverrel %(%{kmodtool} verrel %{?kmod_kernel_version}.%{_target_cpu} 2>/dev/null)
}})dnl

%define upvar ""

%ifarch ppc64
%define kdumpvar kdump
%endif

ifelse(__OSDIST__,{{.EL}},{{dnl
%ifarch i686
%define paevar hugemem
%define smpvar smp
%endif
%ifarch x86_64
%define smpvar smp largesmp
%endif
%ifarch i686 ia64 x86_64
%define xenvar xenU
%endif
}},__OSDIST__,{{.el5}},{{dnl
%ifarch i686
%define paevar PAE
%endif
%ifarch i686 ia64 x86_64
%define xenvar xen
%endif
}})dnl

# hint: this can he overridden with "--define kvariants foo bar" on the
# rpmbuild command line, e.g. --define 'kvariants "" smp'
%{!?kvariants: %define kvariants %{?upvar} %{?smpvar} %{?xenvar} %{?kdumpvar} %{?paevar}}

# Use kmodtool to generate individual kmod subpackages directives.
# Hack in our own preinstall script.
ifelse(__OSDIST__,{{.EL}},{{dnl
%define kmodtemplate rpmtemplate_kmp
}},__OSDIST__,{{.el5}},{{dnl
%define kmodtemplate rpmtemplate_kmp
}},{{dnl
%define kmodtemplate rpmtemplate
%define kmod_version %{version}
%define kmod_release %{release}
}})dnl
%{expand:%(%{kmodtool} %{kmodtemplate} %{kmod_name} %{kverrel} %{kvariants} 2>/dev/null | sed -e 's@^\(%%preun \)\(.*\)$@%%pre \2\n%{prekmodrm}\n\n\1\2\n%{preunkmodrm}\n@g')}

%description
Enables IPv4 and IPv6 destination address rewriting using iptables rules.

The "iptables-daddr" package provides an iptables user-space
plugin "DADDR" target.  The plugin requires installation of a
"kmod-iptables-daddr" package providing a matching kernel module
for the running kernel.

For further information: %{url}

%prep
%setup -q -n %{name}-%{version}


%build
%__make -f mk/Makefile.rpm KVERREL='%{kverrel}' KVARIANTS='%{kvariants}' all


%install
%__rm -rf -- %{buildroot}
%makeinstall -f mk/Makefile.rpm KVERREL='%{kverrel}' KVARIANTS='%{kvariants}'


%clean
%__rm -rf -- %{buildroot}


%pre
%{expand:%(echo | sed -e 's@^@%{prekmodrm}@g')}


%preun
%{expand:%(echo | sed -e 's@^@%{preunkmodrm}@g')}


%files
%defattr(-, root, root)
/lib*/xtables/libxt_DADDR.so

%changelog
* Thu Jul 12 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.1-20120712
- Fix problem with DADDR updates being lost with some NICs. 

* Thu Jul 06 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.0-20120706
- Fix problem with checksums on IPv6 causing DADDR not to work with some NICs.

* Tue Oct 04 2011 Quentin Barnes <qbarnes@yahoo-inc.com> 0.5.0-20111004
- First release for RHEL6, includes IPv4 and IPv6 support and uses weak-modules.
