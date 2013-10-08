#
# spec file for package yast2-nfs-client
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-nfs-client
Version:        3.1.0
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0+
BuildRequires:  perl-XML-Writer update-desktop-files yast2-testsuite 
BuildRequires:  yast2-devtools >= 3.0.6
# Don't use Info function to check enable state (bnc#807507)
BuildRequires:  yast2 >= 2.23.23
# yast2-nfs-client depends on nfs-utils in term that edits nfs-utils' options.
# Support was checked against nfs-utils 1.2.7.
# As soon as nfs-utils reaches version 1.2.9 there should be another update.
BuildRequires:	nfs-client < 1.2.9
#ag_showexports moved to yast2 base
# introduces extended IPv6 support.
Requires:       yast2 >= 2.23.6
#idmapd_conf agent
Requires:       yast2-nfs-common >= 2.24.0
# showmount, #150382, #286300
Recommends:     nfs-client

Provides:       yast2-config-nfs yast2-config-nfs-devel
Obsoletes:      yast2-config-nfs yast2-config-nfs-devel
Provides:       yast2-trans-nfs
Obsoletes:      yast2-trans-nfs
Provides:       yast2-config-network:/usr/lib/YaST2/clients/lan_nfs_client.ycp

BuildArch:      noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - NFS Configuration
Url:            http://en.opensuse.org/Portal:YaST

%description
The YaST2 component for configuration of NFS. NFS stands for network
file system access. It allows access to files on remote machines.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/nfs
%{yast_yncludedir}/nfs/*
%dir %{yast_clientdir}
%{yast_clientdir}/nfs.rb
%{yast_clientdir}/nfs-client.rb
%{yast_clientdir}/nfs_auto.rb
%{yast_clientdir}/nfs-client4part.rb
%dir %{yast_moduledir}
%{yast_moduledir}/Nfs.rb
%{yast_moduledir}/NfsOptions.rb
%dir %{yast_desktopdir}
%{yast_desktopdir}/nfs.desktop
%doc %{yast_docdir}
%{yast_schemadir}/autoyast/rnc/nfs.rnc

%changelog
