# syntax=docker/dockerfile:1
FROM ghcr.io/ublue-os/base-main:44

# 1. 配置软件源 (v2rayA Copr 源)
RUN cat << 'EOF' > /etc/yum.repos.d/_copr_zhullyb-v2rayA.repo
[copr:copr.fedorainfracloud.org:zhullyb:v2rayA]
name=Copr repo for v2rayA owned by zhullyb
baseurl=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/fedora-44-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

# 2. 安装 RPM 软件包并固化 OSTree 层
RUN rpm-ostree install \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    atril \
    btop \
    dbus-x11 \
    engrampa \
    fastfetch \
    firewalld \
    galculator \
    git \
    gnome-terminal \
    hicolor-icon-theme \
    htop \
    labwc \
    lxqt-themes \
    lxqt-themes-fedora \
    lxqt-about \
    lxqt-config \
    lxqt-globalkeys \
    lxqt-notificationd \
    lxqt-openssh-askpass \
    lxqt-panel \
    lxqt-policykit \
    lxqt-qtplugin \
    lxqt-runner \
    lxqt-session \
    lxqt-wayland-session \
    lxqt-labwc-session \
    meld \
    mesa-dri-drivers \
    open-vm-tools-desktop \
    pluma \
    polkit \
    pcmanfm-qt \
    qterminal \
    screengrab \
    sddm \
    syncthing \
    thunar \
    thunar-archive-plugin \
    v2raya \
    wayvnc \
    xorg-x11-drv-vmware \
    xorg-x11-server-Xwayland \
    xdg-desktop-portal-gtk \
    xdg-user-dirs \
    xdg-desktop-portal && \
    ostree container commit

# 3. 预装系统级 Flatpak 应用
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
    flatpak --system install -y flathub \
      com.google.Chrome \
      com.visualstudio.code \
      org.mozilla.firefox \
      com.github.tchx84.Flatseal \
      io.missioncenter.MissionCenter \
      io.github.peazip.PeaZip \
      net.nokyan.Resources \
      com.xnview.XnViewMP

# 4. 系统环境与登录配置
RUN echo "WLR_NO_HARDWARE_CURSORS=1" >> /etc/environment && \
    echo "XDG_CURRENT_DESKTOP=LXQt:labwc:wlroots" >> /etc/environment && \
    echo "XDG_SESSION_TYPE=wayland" >> /etc/environment && \
    mkdir -p /var/lib/systemd/linger && \
    touch /var/lib/systemd/linger/edward && \
    touch /var/lib/systemd/linger/bob && \
    firewall-offline-cmd --add-port=5900/tcp && \
    firewall-offline-cmd --add-port=8384/tcp && \
    mkdir -p /etc/sddm.conf.d && \
    cat << 'EOF' > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=edward
Session=lxqt-wayland
[General]
DisplayServer=wayland
EOF

# 5. 配置用户级 Systemd 单元文件 (WayVNC 与 Syncthing)
RUN mkdir -p /usr/lib/systemd/user/ && \
    cat << 'EOF' > /usr/lib/systemd/user/wayvnc.service
[Unit]
Description=WayVNC Service
After=wayland-session.target

[Service]
Type=simple
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=%t
ExecStartPre=/usr/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR
ExecStart=/usr/bin/wayvnc --render-cursor 0.0.0.0 5900
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

RUN cat << 'EOF' > /usr/lib/systemd/user/syncthing.service
[Unit]
Description=Syncthing Service
After=network.target

[Service]
Environment=HOME=%h
ExecStartPre=/usr/bin/mkdir -p %h/.config/syncthing
ExecStart=/usr/bin/syncthing serve --no-browser --no-restart --gui-address=127.0.0.1:8384
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

# 6. 激活系统服务与全局用户服务
RUN systemctl enable sddm.service v2raya.service vmtoolsd.service firewalld.service && \
    systemctl --global enable wayvnc.service syncthing.service
