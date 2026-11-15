%{!?pkgversion: %global pkgversion 0.1.0}

Name:           snry-kde
Version:        %{pkgversion}
Release:        1%{?dist}
Summary:        Hyprland-style KWin workspaces and an HTPC couch/desktop mode widget for Plasma 6
License:        GPL-3.0-or-later
URL:            https://github.com/sonroyaalmerol/snry-kde
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make

Requires:       bash
Requires:       kwin
Requires:       plasma-workspace
Requires:       jq
Requires:       /usr/bin/kscreen-doctor
Requires:       /usr/bin/pactl
Requires:       /usr/bin/kreadconfig6
Requires:       /usr/bin/kwriteconfig6
Requires:       /usr/bin/kpackagetool6
Requires:       /usr/bin/notify-send
Requires:       /usr/bin/gdbus
Requires:       /usr/bin/flock
Requires:       /usr/bin/pgrep
Recommends:     curl
Suggests:       kdeconnectd
Suggests:       kodi
Suggests:       gamescope

%description
snry-kde bundles a KWin script that gives Hyprland-style per-monitor workspaces
on Plasma 6.7+ per-screen virtual desktops, a Plasma widget and CLI (snry-htpc)
that switch between desktop monitors and a TV with audio routing and Kodi /
Steam Big Picture launchers, and snry-kde-setup for per-user configuration.

%prep
%autosetup

%build

%install
%make_install PREFIX=%{_prefix} VERSION=%{version}

%files
%license LICENSE
%doc README.md
%{_bindir}/snry-htpc
%{_bindir}/snry-kde-setup
%{_datadir}/kwin/scripts/snry-workspaces/
%{_datadir}/plasma/plasmoids/me.snry.htpc/
%{_datadir}/applications/me.snry.htpc.desktop
%{_datadir}/snry-kde/
%exclude %{_datadir}/doc/snry-kde/README.md

%changelog
* Sun Nov 15 2026 Son Roy Almerol <github@snry.me> - 0.1.0-1
- Initial package
