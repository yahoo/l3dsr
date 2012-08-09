changequote({{,}})dnl
%define kmod_name               __PACKAGE__
%define kmod_driver_version     __VERSION__
%define kmod_rpm_release        __RELEASE__
%define kmod_kernel_version     __KVERREL__

Summary: Iptables IPv4 destination address rewriting
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
BuildRequires: iptables-devel >= 1.3.5-5.3, iptables-devel < 1.4
Requires: iptables >= 1.3.5, iptables < 1.4
Requires: %{name}-kmod >= %{version}

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%package -n iptables-ipv6-daddr
Summary: Iptables IPv6 destination address rewriting
Group: Applications/System
Requires: iptables-ipv6 >= 1.3.5, iptables-ipv6 < 1.4
Requires: %{name}-kmod >= %{version}

%define _prefix %{nil}
%define rpmversion %{version}-%{release}
%define fullpkgname %{name}-%{rpmversion}

Source: %{name}-%{version}.tar.bz2

%define kmodtool sh /usr/lib/rpm/redhat/kmodtool

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
%{!?kvariants: %define kvariants %{?upvar} %{?xenvar} %{?kdumpvar} %{?paevar}}

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
Enables IPv4 destination address rewriting using iptables rules.

The "iptables-daddr" package provides an iptables user-space
plugin "DADDR" target.  The plugin requires installation of a
"kmod-iptables-daddr" package providing a matching kernel module
for the running kernel.

For further information: %{url}

%description -n iptables-ipv6-daddr
Enables IPv6 destination address rewriting using iptables rules.

The "iptables-ipv6-daddr" package provides an iptables user-space
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


%pre -n iptables-ipv6-daddr
%{expand:%(echo | sed -e 's@^@%{prekmodrm}@g')}


%preun
%{expand:%(echo | sed -e 's@^@%{preunkmodrm}@g')}


%preun -n iptables-ipv6-daddr
%{expand:%(echo | sed -e 's@^@%{preunkmodrm}@g')}


%files
%defattr(-, root, root)
/lib*/iptables/libipt_DADDR.so


%files -n iptables-ipv6-daddr
%defattr(-, root, root)
/lib*/iptables/libip6t_DADDR.so


%changelog
* Thu Jul 05 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.0-20120705
- Add IPv6 support.

* Wed Dec 14 2011 Quentin Barnes <qbarnes@yahoo-inc.com> 0.5.0-20111214
- Eliminate dependency on YlkmMgr, now using standard 'weak-modules' approach.
- Convert package over to building using standard 'kmodtool'.
- Split into separate binary packages for iptables plugin and each LKM.

* Sat Jan 15 2011 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.1-20110121
- Add xen kernel support.  [BZ #4237848]
- Fix theoretical packaging dependency and some more "rpm -U ..." problems.
- Can remove libiptc headers since now included in later iptables-devel RPMs.

* Fri Oct 1 2010 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.0-20101001
- Fix function argument problem that caused address to be changed incorrectly. [#4032170]
- Fix problem when running "rpm -U ..." on package.
 
* Fri Aug 6 2010 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.0-20100806
- Update to use the new statically configuring ylkmmgr 0.2.0. 
 
* Sun Jul 12 2009 Quentin Barnes <qbarnes@yahoo-inc.com> 0.1.1-20090712
- Update for RHEL5.

* Mon Sep 11 2008 Quentin Barnes <qbarnes@yahoo-inc.com> 0.1-20080911
- Initial release
