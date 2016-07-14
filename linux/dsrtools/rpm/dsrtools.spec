%if 0%{!?rhel_version:1}
  %if 0%{?dist:1}
    %if "%{dist}" == ".el5"
      %define rhel_version 505
    %endif
    %if "%{dist}" == ".el6"
      %define rhel_version 600
    %endif
    %if "%{dist}" == ".el7"
      %define rhel_version 700
    %endif
  %endif
%endif

%if 0%{!?pkg_name:1}
  %define pkg_name dsrtools
%endif
%if 0%{!?pkg_version:1}
  %define pkg_version 1.1.0
%endif
%if 0%{!?pkg_release:1}
  %define pkg_release 20160714
%endif

Summary: DSR tools
Name: %{pkg_name}
Version: %{pkg_version}
Release: %{pkg_release}%{?build_number:.%{build_number}}%{?dist}
License: GPLv2
Group: System Environment/System
%if 0%{?url:1}
URL: %{url}
%endif
Vendor: Yahoo Inc.
Packager: Wayne Badger <badger@yahoo-inc.com>

%define with_systemd  %{?_without_systemd:0}%{?!_without_systemd:1}

%if 0%{?rhel_version} < 700
%define with_systemd 0
%endif

%define cmdfile dsrctl
%define rcfile dsr
%define man5file dsr.conf.5
%define man8file dsrctl.8
%define dsrservice dsr.service
%define dsrreadme README

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
Requires: ksh iptables iproute iptables-daddr kmod-iptables-daddr

%if %{with_systemd}
Requires: systemd
BuildRequires: systemd
%endif


Source: %{name}-%{version}.tar.bz2

%description
dsrtools is a package that manages DSR (Direct Server Return) machines by
initializing DSR for them during the boot sequence.  Both L3DSR and L2DSR are
supported.  The dsrctl command handles configuration and startup as well as
displaying status information.

%prep
%setup -q

%build
%__make -C src PACKAGE=%{name} VERSION=%{version} RELEASE=%{release} INSTDIR='%{buildroot}' WITHSYSTEMD=%{with_systemd} all

%install
%__rm -rf -- '%{buildroot}'
%makeinstall -C src PACKAGE=%{name} VERSION=%{version} RELEASE=%{release} INSTDIR='%{buildroot}' WITHSYSTEMD=%{with_systemd}

%clean
%__rm -rf -- '%{buildroot}'

%post
%if %{with_systemd}
  systemctl start %{dsrservice}
  systemctl enable %{dsrservice} || :
%else
  chkconfig dsr on
  service dsr start
%endif

%preun
[ $1 = 0 ] || exit 0
%if %{with_systemd}
  systemctl stop %{dsrservice} || :
  systemctl --no-reload disable %{dsrservice} || :
%else
  service dsr stop || :
  chkconfig dsr off || :
%endif

%files

%defattr(0755, root, root)
%dir %{_sysconfdir}/dsr.d
%{_sbindir}/%{cmdfile}
%if ! %{with_systemd}
  %{_initrddir}/%{rcfile}
%endif

%defattr(0644, root, root)
%{_sysconfdir}/dsr.d/%{dsrreadme}
%if %{with_systemd}
  %{_unitdir}/%{dsrservice}
%endif
%{_mandir}/man5/%{man5file}.gz
%{_mandir}/man8/%{man8file}.gz


%changelog
* Thu Jul 14 2016 Wayne Badger <badger@yahoo-inc.com> 1.1.0-20160714
- Refactor build environment.

* Mon Apr 20 2015 Wayne Badger <badger@yahoo-inc.com> 1.0.0-20150420
- Initial release.
