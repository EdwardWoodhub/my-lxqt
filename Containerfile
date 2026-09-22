# 1. 基础镜像
FROM quay.io/fedora/fedora-bootc:44

# 2. 配置软件源 (使用兼容的 fedora-43 编译包路径，避免 rawhide 404)
RUN printf '[copr:copr.fedorainfracloud.org:zhullyb:v2rayA]\nname=Copr repo for v2rayA owned by zhullyb\nbaseurl=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/fedora-43-$basearch/\ntype=rpm-md\nskip_if_unavailable=True\ngpgcheck=1\ngpgkey=https://download.copr.fedorainfracloud.org/results/zhullyb/v2rayA/pubkey.gpg\nrepo_gpgcheck=0\nenabled=1\nenabled_metadata=1\n' > /etc/yum.repos.d/_copr_zhullyb-v2rayA.repo

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
    printf '[Autologin]\nUser=edward\nSession=lxqt-wayland\n[General]\nDisplayServer=wayland\n' > /etc/sddm.conf.d/autologin.conf

# 7. 配置用户级别的 systemd 服务 (WayVNC 与 Syncthing)
RUN mkdir -p /usr/lib/systemd/user/ && \
    printf '[Unit]\nDescription=WayVNC Service\nAfter=wayland-session.target\n\n[Service]\nType=simple\nEnvironment=WAYLAND_DISPLAY=wayland-0\nEnvironment=XDG_RUNTIME_DIR=%%t\nExecStartPre=/usr/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR\nExecStart=/usr/bin/wayvnc --render-cursor 0.0.0.0 5900\nRestart=always\nRestartSec=10\n\n[Install]\nWantedBy=default.target\n' > /usr/lib/systemd/user/wayvnc.service && \
    printf '[Unit]\nDescription=Syncthing Service\nAfter=network.target\n\n[Service]\nEnvironment=HOME=%%h\nExecStartPre=/usr/bin/mkdir -p %%h/.config/syncthing\nExecStart=/usr/bin/syncthing serve --no-browser --no-restart --gui-address=127.0.0.1:8384\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=default.target\n' > /usr/lib/systemd/user/syncthing.service

# 8. 启用系统级与用户级服务软链接
RUN systemctl enable sddm.service v2raya.service vmtoolsd.service firewalld.service && \
    mkdir -p /usr/lib/systemd/user/default.target.wants && \
    ln -sf /usr/lib/systemd/user/wayvnc.service /usr/lib/systemd/user/default.target.wants/wayvnc.service && \
    ln -sf /usr/lib/systemd/user/syncthing.service /usr/lib/systemd/user/default.target.wants/syncthing.service

# 9. Flatpak 自动预装配置
RUN mkdir -p /etc/flatpak/remotes.d && \
    printf '#!/bin/bash\nflatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo\nFLATPAKS=(\n  com.google.Chrome\n  com.visualstudio.code\n  org.mozilla.firefox\n  com.github.tchx84.Flatseal\n  io.missioncenter.MissionCenter\n  io.github.peazip.PeaZip\n  net.nokyan.Resources\n  com.xnview.XnViewMP\n)\nfor app in "${FLATPAKS[@]}"; do\n  flatpak install --system -y flathub "$app" || true\ndone\nsystemctl disable install-flatpaks.service\n' > /usr/libexec/install-flatpaks.sh && \
    chmod +x /usr/libexec/install-flatpaks.sh && \
    printf '[Unit]\nDescription=Initial Flatpak Applications Installation\nAfter=network-online.target\nWants=network-online.target\nConditionPathExists=!/var/lib/flatpaks-installed\n\n[Service]\nType=oneshot\nExecStart=/usr/libexec/install-flatpaks.sh\nExecStartPost=/usr/bin/touch /var/lib/flatpaks-installed\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /usr/lib/systemd/system/install-flatpaks.service && \
    systemctl enable install-flatpaks.service
