# Options --
#   with_kmod:     Disable generation of the kmod package
#   with_mangle:   Set table from default of raw to mangle
#   with_override: Enable kmod override rule
%define with_kmod	%{?_without_kmod:0}  %{?!_without_kmod:1}
%define with_mangle	%{?_with_mangle:1}   %{?!_with_mangle:0}
%define with_override	%{?_with_override:1} %{?!_with_override:0}


%if 0%{!?kmod_name:1}
  %define kmod_name iptables-daddr
%endif
%if 0%{!?kmod_driver_version:1}
  %define kmod_driver_version 0.10.0
%endif
%if 0%{!?kmod_rpm_release:1}
  %define kmod_rpm_release 20190912
%endif

%if 0%{!?iptables_version_maj:1}
  %define iptables_version_maj 1
%endif
%if 0%{!?iptables_version_min:1}
  %define iptables_version_min 4
%endif

%define extensionsdir extensions-%{iptables_version_maj}.%{iptables_version_min}

%if %{with_kmod}
  %define kmoddir kmod-xt
  %define pkgko xt_DADDR
%endif

%define _prefix %{nil}


Summary: Iptables destination address rewriting for IPv4 and IPv6
Name: %{kmod_name}
Version: %{kmod_driver_version}
Release: %{kmod_rpm_release}%{?build_id:.%{build_id}}%{?dist}
License: GPLv2
Group: Applications/System
%if 0%{?url:1}
URL: %{url}
%endif
Vendor: Oath Inc.
Packager: Quentin Barnes <qbarnes@verizonmedia.com>

%if 0%{?rhel:1}
BuildRequires: iptables-devel >= 1.4.7, iptables-devel < 1.9
Requires: iptables >= 1.4.7, iptables < 1.9
  %if %{with_kmod}
Requires: %{name}-kmod = %{version}-%{release}
    %if 0%{?rhel} < 7
BuildRequires: module-init-tools
    %else
BuildRequires: kmod
    %endif
BuildRequires: redhat-rpm-config >= 9.0.3-51
BuildRequires: kernel-abi-whitelists
BuildRequires: kernel-devel
  %endif
%endif

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Source0: %{name}-%{version}.tar.xz
Source1: %{name}.files

%if %{with_kmod}
  # Note: Can't indent kernel_module_package macro.
  # Build only for standard kernel variant(s); for debug packages,
  # append "debug" after "default" (separated by a space).
%kernel_module_package -f %{SOURCE1} default
%endif

%description
Enables IPv4 and IPv6 destination address rewriting using iptables rules.

The "%{name}" package provides an iptables user-space plugin "DADDR"
target.  The plugin requires installation of a "kmod-%{name}"
package providing a matching kernel module for the running kernel or
the "%{pkgko}" module integrated into the kernel.

%prep
%setup -q -c -T -a 0


%build
%__make -C '%{name}-%{version}/%{extensionsdir}' all
%if %{with_kmod}
  for flavor in %{flavors_to_build}
  do
    rm -rf "_kmod_build_$flavor"
    cp -a -- '%{name}-%{version}' "_kmod_build_$flavor"

    %__make \
      -C "%{kernel_source $flavor}" \
      M="$PWD/_kmod_build_${flavor}/%{kmoddir}" \
      MODVERSION='%{kmod_driver_version}'
  done
%endif


%install
%__rm -rf -- '%{buildroot}'
%makeinstall -C '%{name}-%{version}/%{extensionsdir}'
%if %{with_kmod}
  for flavor in %{flavors_to_build}
  do
    flavorext=$([ $flavor = default ] || echo $flavor)
    kodir="%{buildroot}/lib/modules/%{kverrel}${flavorext}/extra/%{name}"
    %__make \
      -C "%{kernel_source $flavor}" \
      M="$PWD/_kmod_build_${flavor}/%{kmoddir}" \
      MODVERSION='%{kmod_driver_version}'
    # Make sure execute bits are set so that strip-to-file can strip them.
    install -m 755 -D \
      "_kmod_build_${flavor}/%{kmoddir}/%{pkgko}.ko" \
      "$kodir/%{pkgko}.ko"
  done
  %if %{with_mangle}
    %__mkdir_p -- "$RPM_BUILD_ROOT/etc/modprobe.d"
    echo "options %{pkgko} table=mangle" > \
      $RPM_BUILD_ROOT/etc/modprobe.d/%{pkgko}.conf
  %endif
  %if %{with_override}
    %__mkdir_p -- "$RPM_BUILD_ROOT/etc/depmod.d"
    echo "override %{pkgko} * weak-updates/%{name}" > \
      $RPM_BUILD_ROOT/etc/depmod.d/%{name}.conf
  %endif
%endif


%clean
%__rm -rf -- '%{buildroot}'


%files
%defattr(-, root, root)
/lib*/xtables/libxt_DADDR.so


%changelog
* Thu Sep 12 2019 Quentin Barnes <qbarnes@verizonmedia.com> 0.10.0-20190912
- Fix "hw csum failure" for ICMP packets when in CHECKSUM_COMPLETE mode.
- Fix UDP checksum value when recomputed checksum is 0.
- Add check to skip UDP checksum recomputation when checksum is ignored.
- Check for and handle IPv6 packets without transport payload or corrupt.
- Handle checksum recomputation for IPPROTO_ICMPV6 packets.
- Add copy of inet_proto_csum_replace16() for kernels without the function.
- No longer call kmodtool directly.  Use kernel_module_package macro instead.
- Add "--with mangle" and "--with override" build options.

* Thu Aug 01 2019 Quentin Barnes <qbarnes@verizonmedia.com> 0.9.1-20190801
- Fix "hw csum failure" when NIC drivers send up CHECKSUM_COMPLETE packets.

* Fri Jul 19 2019 Quentin Barnes <qbarnes@verizonmedia.com> 0.9.0-20190719
- Correct kmodtool macro error that fails package remove.

* Thu Mar 21 2019 Quentin Barnes <qbarnes@oath.com> 0.9.0-20190321
- Remove pre and preun checks for kernel module being unused.
- Add RHEL 8 support.
- Convert from build_number to build_id macro.

* Fri Mar 08 2019 Quentin Barnes <qbarnes@oath.com> 0.9.0-20190308
- Add table parameter to module.  Change default from mangle to raw.
- Switch tar file format from .bz2 to .xz.

* Thu Mar 07 2019 Quentin Barnes <qbarnes@oath.com> 0.8.0-20190307
- Add "--without kmod" option to prevent generation of the kmod package.

* Wed Mar 06 2019 Quentin Barnes <qbarnes@oath.com> 0.8.0-20190306
- Drop support for RHEL 4 and RHEL 5.

* Wed Jul 11 2018 Quentin Barnes <qbarnes@oath.com> 0.8.0-20180711
- Print appropriate leading or trailing whitespace for messages.

* Thu Feb 04 2016 Quentin Barnes <qbarnes@yahoo-inc.com> 0.7.0-20160204
- Packaging only changes for primarily building with mock.

* Wed Mar 04 2015 Quentin Barnes <qbarnes@yahoo-inc.com> 0.7.0-20150304
- Packaging only changes for some RHEL7 tweaks.

* Wed Mar 19 2014 Quentin Barnes <qbarnes@yahoo-inc.com> 0.7.0-20140319
- Add explicit support for UDP.
- Fix problem with code assuming all IPv6 packets are TCP.
- Fix problem with NICs that don't do TCP offloading including virtio_net.

* Sun Aug 18 2013 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.2-20130818
- Update to new build process.
- Synchronize all released versions.

* Sat Jul 28 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.0-20120728
- First release for Fedora 17.

* Thu Jul 12 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.1-20120712
- Fix problem with DADDR updates being lost with some NICs.

* Thu Jul 05 2012 Quentin Barnes <qbarnes@yahoo-inc.com> 0.6.0-20120705
- Add IPv6 support.

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

* Thu Sep 11 2008 Quentin Barnes <qbarnes@yahoo-inc.com> 0.1-20080911
- Initial release
