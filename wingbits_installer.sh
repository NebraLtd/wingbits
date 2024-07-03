#!/usr/bin/env bash
set -e

arch="$(dpkg --print-architecture)"
echo System Architecture: $arch

cd /tmp

# install vector

curl -1sLf 'https://repositories.timber.io/public/vector/cfg/setup/bash.deb.sh' | sudo -E bash
bash -c "$(curl -L https://setup.vector.dev)"
apt-get -y install vector

# install readsb
sudo apt update
sudo apt install --no-install-recommends --no-install-suggests -y \
    git build-essential debhelper libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 pkg-config \
    libncurses-dev zlib1g-dev zlib1g libzstd-dev libzstd1
git clone --depth 20 https://github.com/wiedehopf/readsb.git
cd readsb
export DEB_BUILD_OPTIONS=noddebs
dpkg-buildpackage -b -Prtlsdr -ui -uc -us
sudo dpkg -i ../readsb_*.deb

# curl -sL https://github.com/wiedehopf/adsb-scripts/raw/master/readsb-install.sh | bash

# install graphs1090
curl -sL https://github.com/wiedehopf/graphs1090/raw/master/install.sh | bash

# install tar1090

