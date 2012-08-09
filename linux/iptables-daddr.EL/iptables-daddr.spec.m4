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
BuildRequires: iptables-devel >= 1.2.11, iptables-devel < 1.3
Requires: iptables >= 1.2.11, iptables < 1.3
Requires: module-init-tools >= 3.1-0.pre5.3.10
Requires: %{name}-kmod >= %{version}

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%define _prefix %{nil}
%define rpmversion %{version}-%{release}
%define fullpkgname %{name}-%{rpmversion}

Source: %{name}-%{version}.tar.bz2
Source1: kmodtool

%define kmodtool sh %{SOURCE1}

# Create a preinstall and preuninstall scripts as a macro for processing
# with sed that ensures any existing ipt_DADDR module, if present, can
# be removed.  If not, fail.
%define pkgko ipt_DADDR
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

# hint: this can he overridden with "--define kvariant foo bar" on the
# rpmbuild command line, e.g. --define 'kvariant "" smp'
%{!?kvariants: %define kvariants %{?upvar} %{?smpvar} %{?xenvar} %{?kdumpvar} %{?paevar}}
%{!?kvariants1: %define kvariants1 %{?upvar} %{?smpvar}}
%{!?kvariants2: %define kvariants2 %{?xenvar} %{?kdumpvar} %{?paevar}}

# Use kmodtool to generate individual kmod subpackages directives.
# Had to break the kmodtool output up into two.  The expand seems to hit a
# buffer overflow problem.
ifelse(__OSDIST__,{{.EL}},{{dnl
%define kmodtemplate rpmtemplate_kmp
}},__OSDIST__,{{.el5}},{{dnl
%define kmodtemplate rpmtemplate_kmp
}},{{dnl
%define kmodtemplate rpmtemplate
%define kmod_version %{version}
%define kmod_release %{release}
}})dnl
%{expand:%(%{kmodtool} rpmtemplate_kmp %{kmod_name} %{kverrel} %{kvariants1} 2>/dev/null | sed -e 's@^\(%%preun \)\(.*\)$@%%pre \2\n%{prekmodrm}\n\1\2\n%{preunkmodrm}@g')}
%{expand:%(%{kmodtool} rpmtemplate_kmp %{kmod_name} %{kverrel} %{kvariants2} 2>/dev/null | sed -e 's@^\(%%preun \)\(.*\)$@%%pre \2\n%{prekmodrm}\n\1\2\n%{preunkmodrm}@g')}

%description
Enables IPv4 destination address rewriting using iptables rules.

The %{name} package provides an iptables user-space
plugin "DADDR" target.  The plugin requires installation of a
"kmod-%{name}" package providing a matching kernel module for
the running kernel.

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
/lib*/iptables/libipt_DADDR.so


%changelog
* Wed Nov 23 2011 Quentin Barnes <qbarnes@yahoo-inc.com> 0.5.0-20111123
- Eliminate dependency on YlkmMgr, now using standard 'weak-modules' approach.
- Convert package over to building using standard 'kmodtool'.
- Split into separate binary packages for iptables plugin and each LKM.

* Sat Jan 15 2011 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.1-20110115
- Add xenU kernel support.  [BZ #4237848]
- Fix theoretical packaging dependency and some more "rpm -U ..." problems.

* Fri Oct 1 2010 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.0-20101001
- Fix problem when running "rpm -U ..." on package.

* Fri Aug 6 2010 Quentin Barnes <qbarnes@yahoo-inc.com> 0.2.0-20100806
- Update to use the new statically configuring ylkmmgr 0.2.0.

* Tue Nov 3 2009 Quentin Barnes <qbarnes@yahoo-inc.com> 0.1.1-20091103
- Update Makefiles to simplify build.
- Fix uninstall problems to remove kernel module if loaded.

* Mon Sep 11 2008 Quentin Barnes <qbarnes@yahoo-inc.com> 0.1-20080911
- Initial release
