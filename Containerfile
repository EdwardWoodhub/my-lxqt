FROM quay.io/fedora/fedora-bootc:44

# 1. 配置软件源 (v2rayA Copr 源)
RUN { \
    echo '[copr:copr.fedorainfracloud.org:zhullyb:v2rayA]'; \
    echo 'name=Copr repo for v2rayA owned by zhullyb'; \
    echo 'baseurl=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/fedora-$releasever-$basearch/'; \
    echo 'type=rpm-md'; \
    echo 'skip_if_unavailable=True'; \
    echo 'gpgcheck=1'; \
    echo 'gpgkey=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/pubkey.gpg'; \
    echo 'repo_gpgcheck=0'; \
    echo 'enabled=1'; \
    echo 'enabled_metadata=1'; \
} > /etc/yum.repos.d/_copr_zhullyb-v2rayA.repo

# 2. 安装 RPM 软件包 (纯 dnf)
RUN dnf install -y --setopt=install_weak_deps=False \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    atril \
    btop \
    dbus-x11 \
    engrampa \
    fastfetch \
    firewalld \
    flatpak \
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
    dnf clean all

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
    { \
        echo '[Autologin]'; \
        echo 'User=edward'; \
        echo 'Session=lxqt-wayland'; \
        echo '[General]'; \
        echo 'DisplayServer=wayland'; \
    } > /etc/sddm.conf.d/autologin.conf

# 5. 配置用户级 Systemd 单元文件 (WayVNC 与 Syncthing)
RUN mkdir -p /usr/lib/systemd/user/ && \
    { \
        echo '[Unit]'; \
        echo 'Description=WayVNC Service'; \
        echo 'After=wayland-session.target'; \
        echo ''; \
        echo '[Service]'; \
        echo 'Type=simple'; \
        echo 'Environment=WAYLAND_DISPLAY=wayland-0'; \
        echo 'Environment=XDG_RUNTIME_DIR=%t'; \
        echo 'ExecStartPre=/usr/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR'; \
        echo 'ExecStart=/usr/bin/wayvnc --render-cursor 0.0.0.0 5900'; \
        echo 'Restart=always'; \
        echo 'RestartSec=10'; \
        echo ''; \
        echo '[Install]'; \
        echo 'WantedBy=default.target'; \
    } > /usr/lib/systemd/user/wayvnc.service && \
    { \
        echo '[Unit]'; \
        echo 'Description=Syncthing Service'; \
        echo 'After=network.target'; \
        echo ''; \
        echo '[Service]'; \
        echo 'Environment=HOME=%h'; \
        echo 'ExecStartPre=/usr/bin/mkdir -p %h/.config/syncthing'; \
        echo 'ExecStart=/usr/bin/syncthing serve --no-browser --no-restart --gui-address=127.0.0.1:8384'; \
        echo 'Restart=on-failure'; \
        echo 'RestartSec=10'; \
        echo ''; \
        echo '[Install]'; \
        echo 'WantedBy=default.target'; \
    } > /usr/lib/systemd/user/syncthing.service

# 6. 激活系统服务与全局用户服务
RUN systemctl enable sddm.service v2raya.service vmtoolsd.service firewalld.service && \
    systemctl --global enable wayvnc.service syncthing.service
