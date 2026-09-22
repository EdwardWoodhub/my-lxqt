# 1. 基础镜像
FROM quay.io/fedora/fedora-bootc:44

# 2. 配置软件源 (v2rayA Copr 源)
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

# 3. 安装 RPM 软件包并清理缓存
RUN dnf install -y \
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
    xdg-desktop-portal \
    && dnf clean all

# 4. 系统环境与底层配置
RUN echo "WLR_NO_HARDWARE_CURSORS=1" >> /etc/environment && \
    echo "XDG_CURRENT_DESKTOP=LXQt:labwc:wlroots" >> /etc/environment && \
    echo "XDG_SESSION_TYPE=wayland" >> /etc/environment

# 5. 配置 linger 与防火墙规则
RUN mkdir -p /var/lib/systemd/linger && \
    touch /var/lib/systemd/linger/edward && \
    touch /var/lib/systemd/linger/bob && \
    firewall-offline-cmd --add-port=5900/tcp && \
    firewall-offline-cmd --add-port=8384/tcp

# 6. 配置 SDDM 自动登录
RUN mkdir -p /etc/sddm.conf.d && \
    cat << 'EOF' > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=edward
Session=lxqt-wayland
[General]
DisplayServer=wayland
EOF

# 7. 配置用户级别的 systemd 服务 (WayVNC 与 Syncthing)
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

# 8. 启用系统级与用户级服务软链接
RUN systemctl enable sddm.service v2raya.service vmtoolsd.service firewalld.service && \
    mkdir -p /usr/lib/systemd/user/default.target.wants && \
    ln -sf /usr/lib/systemd/user/wayvnc.service /usr/lib/systemd/user/default.target.wants/wayvnc.service && \
    ln -sf /usr/lib/systemd/user/syncthing.service /usr/lib/systemd/user/default.target.wants/syncthing.service

# 9. Flatpak 自动预装配置 (替代 recipe 中的 default-flatpaks 模块)
RUN mkdir -p /etc/flatpak/remotes.d && \
    cat << 'EOF' > /usr/libexec/install-flatpaks.sh
#!/bin/bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
FLATPAKS=(
  com.google.Chrome
  com.visualstudio.code
  org.mozilla.firefox
  com.github.tchx84.Flatseal
  io.missioncenter.MissionCenter
  io.github.peazip.PeaZip
  net.nokyan.Resources
  com.xnview.XnViewMP
)
for app in "${FLATPAKS[@]}"; do
  flatpak install --system -y flathub "$app" || true
done
systemctl disable install-flatpaks.service
EOF
RUN chmod +x /usr/libexec/install-flatpaks.sh

RUN cat << 'EOF' > /usr/lib/systemd/system/install-flatpaks.service
[Unit]
Description=Initial Flatpak Applications Installation
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/flatpaks-installed

[Service]
Type=oneshot
ExecStart=/usr/libexec/install-flatpaks.sh
ExecStartPost=/usr/bin/touch /var/lib/flatpaks-installed
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

RUN systemctl enable install-flatpaks.service
