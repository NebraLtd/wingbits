#!/usr/bin/env bash
set -e

arch="$(dpkg --print-architecture)"
echo System Architecture: $arch

cd /tmp

# install vector

curl -1sLf 'https://repositories.timber.io/public/vector/cfg/setup/bash.deb.sh' | sudo -E bash
bash -c "$(curl -L https://setup.vector.dev)"
apt-get -y install vector

# install tar1090
if [[ -z "$NO_TAR1090" ]] ; then
    wget -O tar1090-install.sh https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh
    bash tar1090-install.sh /run/readsb
fi
