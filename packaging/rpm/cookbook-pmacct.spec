%global cookbook_path /var/chef/cookbooks/pmacct

Name: cookbook-pmacct
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: pmacct cookbook to install and configure it in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-pmacct
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%{cookbook_path}
cp -f -r  resources/* %{buildroot}%{cookbook_path}
chmod -R 0755 %{buildroot}%{cookbook_path}
install -D -m 0644 README.md %{buildroot}%{cookbook_path}/README.md

%pre

%post

%files
%defattr(0755,root,root)
%{cookbook_path}
%defattr(0644,root,root)
%{cookbook_path}/README.md

%doc

%changelog
* Thu Feb 8 2018 Juan J. Prieto <jjprieto@redborder.com> - 0.0.1-1
- first spec version
