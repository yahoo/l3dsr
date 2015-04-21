%if 0%{!?pkg_name:1}
  %define pkg_name dsrtools
%endif
%if 0%{!?pkg_version:1}
  %define pkg_version 1.0
%endif
%if 0%{!?pkg_release:1}
  %define pkg_release 20150312
%endif

Summary: DSR tools
Name: %{pkg_name}
Version: %{pkg_version}
Release: %{pkg_release}%{?dist}
License: Proprietary
Group: System Environment/System
URL: http://twiki.corp.yahoo.com/view/Platform/Dsrtools
Vendor: Yahoo! Inc.
Packager: Wayne Badger <badger@yahoo-inc.com>

%define cmdfile dsrctl
%define rcfile dsr
%define man5file dsr.conf.5
%define man8file dsrctl.8
%define dsrservice dsr.service
%define dsrreadme README

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
Requires: ksh iptables iproute iptables-daddr kmod-iptables-daddr


Source: %{name}-%{version}.tar.bz2

%description
dsrtools is a package the manages DSRs (direct server return machines) by
initializing DSR for them during the boot sequence.  Both L3DSR and L2DSR are
supported.  The dsrctl command handles configuration and startup as well as
displaying status information.

%prep
%setup -q

%build
%__make -C src PACKAGE=%{name} VERSION=%{version} RELEASE=%{release} DIST=%{?dist} INSTDIR='%{buildroot}' all

%install
%__rm -rf -- '%{buildroot}'
%makeinstall -C src PACKAGE=%{name} VERSION=%{version} RELEASE=%{release} DIST=%{?dist} INSTDIR='%{buildroot}'

%clean
%__rm -rf -- '%{buildroot}'

%post
%if 0%{?rhel_version} >= 700
  systemctl start %{dsrservice}
  systemctl enable %{dsrservice} || :
%else
  chkconfig dsr on
  service dsr start
%endif

%preun
[ $1 = 0 ] || exit 0
%if 0%{?rhel_version} >= 700
  systemctl stop %{dsrservice} || :
  systemctl --no-reload disable %{dsrservice} || :
%else
  service dsr stop || :
  chkconfig dsr off || :
%endif

%files

%defattr(0755, root, root)
%dir %{_sysconfdir}/dsr.d
%{_sysconfdir}/dsr.d/%{dsrreadme}
%{_sbindir}/%{cmdfile}
%if 0%{?rhel_version} >= 700
  %{_unitdir}/%{dsrservice}
%else
  %{_initrddir}/%{rcfile}
%endif

%defattr(0644, root, root)
%{_mandir}/man5/%{man5file}.gz
%{_mandir}/man8/%{man8file}.gz


%changelog
* Thu Mar 12 2015 Wayne Badger <badger@yahoo-inc.com> 1.0-20150312
- Initial release.
