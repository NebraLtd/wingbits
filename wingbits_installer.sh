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
curl -sL https://github.com/wiedehopf/adsb-scripts/raw/master/readsb-install.sh | bash

# install graphs1090
curl -sL https://github.com/wiedehopf/graphs1090/raw/master/install.sh | bash

# install tar1090

