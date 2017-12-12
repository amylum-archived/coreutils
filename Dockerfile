FROM dock0/pkgforge
RUN pacman -S --needed --noconfirm gperf rsync help2man
