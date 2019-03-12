FROM dock0/pkgforge
RUN pacman -S --needed --noconfirm gperf rsync wget
