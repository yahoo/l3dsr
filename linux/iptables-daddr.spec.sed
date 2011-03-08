Summary: Iptables destination address rewriting
Name: __PACKAGE__
Version: __VERSION__
Release: __RELEASE__
License: GPLv2
Group: Applications/System
URL: to-be-filled-in
Vendor: Yahoo! Inc.
Packager: Quentin Barnes <qbarnes@yahoo-inc.com>

%define _prefix %{nil}
%define rpmversion %{version}-%{release}
%define fullpkgname %{name}-%{rpmversion}

BuildRoot: %{_tmppath}/%{fullpkgname}-root
BuildRequires: kernel, kernel-devel, iptables >= 1.3.5, iptables < 1.4
BuildRequires: iptables-devel >= 1.3.5-5.3
Requires: iptables >= 1.3.5, iptables < 1.4

Source: %{fullpkgname}.tar.bz2

%description
This kernel module and iptables plugin enable IP destination address
rewriting using iptables rules.

For information, see: to-be-filled-in

%prep
%setup -q -n %{fullpkgname}

%build
%__make all

%install
%__rm -rf -- %{buildroot}
%makeinstall

%clean
%__rm -rf -- %{buildroot}

%preun
if [ "$1" -eq 0 ]
then
  rmmod '__PACKAGE__' 2> /dev/null || true
  if %__grep -qw '^__PACKAGE__' /proc/modules
  then
    echo >&2 "Failed to rmmod '__PACKAGE__'."
    echo >&2 "Remove iptables rules using DADDR and try again."
    exit 1
  fi
fi

%files
%defattr(-, root, root)
/lib*/iptables/libipt_DADDR.so
/lib/modules/yahoo/__PACKAGE__/Install
%defattr(0744, root, root)
/lib/modules/yahoo/__PACKAGE__/*/ipt_DADDR.ko
%defattr(-, root, root, -)
%dir /
%dir /lib*
%dir /lib*/iptables
%dir /lib/modules
%dir /lib/modules/yahoo
%defattr(-, root, root, 0755)
%dir /lib/modules/yahoo/__PACKAGE__
%dir /lib/modules/yahoo/__PACKAGE__/2.6.*

%changelog
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
