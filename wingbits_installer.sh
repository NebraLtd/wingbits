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
apt update
apt install --no-install-recommends --no-install-suggests -y \
    git build-essential debhelper libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 pkg-config \
    libncurses-dev zlib1g-dev zlib1g libzstd-dev libzstd1
git clone --depth 20 https://github.com/wiedehopf/readsb.git
cd readsb
export DEB_BUILD_OPTIONS=noddebs
dpkg-buildpackage -b -Prtlsdr -ui -uc -us
sudo dpkg -i ../readsb_*.deb

# install graphs1090
repo="https://github.com/wiedehopf/graphs1090"
ipath=/usr/share/graphs1090
install=0

mkdir -p /usr/share/graphs1090/installed
mkdir -p /var/lib/graphs1090/scatter

apt install --no-install-recommends --no-install-suggests -y \
    git rrdtool wget unzip bash-builtins collectd-core libpython3.9
cd /tmp
wget --timeout=30 -q -O /tmp/master.zip https://github.com/wiedehopf/graphs1090/archive/master.zip
unzip -q -o master.zip
cd /tmp/graphs1090-master

CPU_AIR=/run/collectd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd
if [[ -f "$CPU_AIR" ]]; then
    cp "$CPU_AIR" /run/collectd/dump1090_cpu-airspy.rrd
    rrdtool tune --maximum value:U /run/collectd/dump1090_cpu-airspy.rrd
    cp -f /run/collectd/dump1090_cpu-airspy.rrd "$CPU_AIR"
fi

systemctl stop collectd &>/dev/null || true

if [[ -f /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd ]]; then
    rrdtool tune --maximum value:U /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd
fi

cp dump1090.db dump1090.py system_stats.py LICENSE $ipath
cp *.sh $ipath
cp malarky.conf $ipath
chmod u+x $ipath/*.sh
if ! grep -e 'system_stats' -qs /etc/collectd/collectd.conf &>/dev/null; then
	cp /etc/collectd/collectd.conf /etc/collectd/collectd.conf.graphs1090 &>/dev/null || true
	cp collectd.conf /etc/collectd/collectd.conf
	echo "------------------"
	echo "Overwriting /etc/collectd/collectd.conf, the old file has been moved to /etc/collectd/collectd.conf.graphs1090"
	echo "------------------"
fi
if ! grep -qs -e 'RRATimespan 576288000' /etc/collectd/collectd.conf &>/dev/null; then
    sed -i -e 's/RRATimespan 96048000/\0\nRRATimespan 576288000/' /etc/collectd/collectd.conf
fi
sed -i -e 's/XFF.*/XFF 0.8/' /etc/collectd/collectd.conf
sed -i -e 's/skyview978/skyaware978/' /etc/collectd/collectd.conf

# unlisted interfaces
for path in /sys/class/net/*
do
    iface=$(basename $path)
    # no action on existing interfaces
    fgrep -q 'Interface "'$iface'"' /etc/collectd/collectd.conf && continue
    # only add interface starting with et en and wl
    case $iface in
        et*|en*|wl*)
sed -i -e '/<Plugin "interface">/{a\
    Interface "'$iface'"
}' /etc/collectd/collectd.conf
        ;;
    esac
done

rm -f /etc/cron.d/cron-graphs1090
cp -r html $ipath
copyNoClobber default /etc/default/graphs1090
cp default $ipath/default-config
cp collectd.conf $ipath/default-collectd.conf
cp service.service /lib/systemd/system/graphs1090.service
cp nginx-graphs1090.conf $ipath

if [ -d /etc/lighttpd/conf.d/ ] && ! [ -d /etc/lighttpd/conf-enabled/ ] && ! [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null
then
    ln -snf /etc/lighttpd/conf.d /etc/lighttpd/conf-enabled
    mkdir -p /etc/lighttpd/conf-available
fi
if [ -d /etc/lighttpd/conf-enabled/ ] && [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null
then
    lighttpd=yes
fi

if [[ $lighttpd == yes ]]; then
    cp 88-graphs1090.conf /etc/lighttpd/conf-available
    ln -snf /etc/lighttpd/conf-available/88-graphs1090.conf /etc/lighttpd/conf-enabled/88-graphs1090.conf

    cp 95-graphs1090-otherport.conf /etc/lighttpd/conf-available
    ln -snf /etc/lighttpd/conf-available/95-graphs1090-otherport.conf /etc/lighttpd/conf-enabled/95-graphs1090-otherport.conf

    if ! grep -qs -E -e '^[^#]*"mod_alias"' /etc/lighttpd/lighttpd.conf /etc/lighttp/conf-enabled/* /etc/lighttpd/external.conf; then
        echo 'server.modules += ( "mod_alias" )' > /etc/lighttpd/conf-available/07-mod_alias.conf
        ln -s -f /etc/lighttpd/conf-available/07-mod_alias.conf /etc/lighttpd/conf-enabled/07-mod_alias.conf
    else
        rm -f /etc/lighttpd/conf-enabled/07-mod_alias.conf
    fi
fi

SYM=/usr/share/graphs1090/data-symlink
mkdir -p $SYM
if [ -f /run/dump1090-fa/stats.json ]; then
    ln -snf /run/dump1090-fa $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/readsb/stats.json ]; then
    ln -snf /run/readsb $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-feed/stats.json ]; then
    ln -snf /run/adsbexchange-feed $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090/stats.json ]; then
    ln -snf /run/dump1090 $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090-mutability/stats.json ]; then
    ln -snf /run/dump1090-mutability $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
else
    ln -snf /run/readsb $SYM/data
    sed -i -e 's?URL .*?URL "file:///usr/share/graphs1090/data-symlink"?' /etc/collectd/collectd.conf
fi

SYM=/usr/share/graphs1090/978-symlink
mkdir -p $SYM
if [ -f /run/skyaware978/aircraft.json ]; then
    ln -snf /run/skyaware978 $SYM/data
    sed -i -e 's?.*URL_978 .*?URL_978 "file:///usr/share/graphs1090/978-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-978/aircraft.json ]; then
    ln -snf /run/adsbexchange-978 $SYM/data
    sed -i -e 's?.*URL_978 .*?URL_978 "file:///usr/share/graphs1090/978-symlink"?' /etc/collectd/collectd.conf
else
    sed -i -e 's?.*URL_978 .*?#URL_978 "http://localhost/skyaware978"?' /etc/collectd/collectd.conf
fi

if grep jessie /etc/os-release >/dev/null
then
	echo --------------
	echo "Some features are not available on jessie!"
	echo --------------
	sed -i -e 's/ADDNAN/+/' -e 's/TRENDNAN/TREND/' -e 's/MAXNAN/MAX/' -e 's/MINNAN/MIN/' $ipath/graphs1090.sh
	sed -i -e '/axis-format/d' $ipath/graphs1090.sh
fi

if [[ $lighttpd == yes ]]; then
    systemctl restart lighttpd
fi

systemctl enable collectd &>/dev/null
systemctl restart collectd &>/dev/null || true

if ! systemctl status collectd &>/dev/null; then
    echo --------------
    echo "collectd isn't working, trying to install various libpython versions to work around the issue."
    echo --------------
    apt update
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.9' || \
        apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.8' || \
        apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.7' || true

    systemctl restart collectd || true
    if ! systemctl status collectd &>/dev/null; then
        echo --------------
        echo "Showing the log for collectd using this command: journalctl --no-pager -u collectd | tail -n40"
        echo --------------
        journalctl --no-pager -u collectd | tail -n40
        echo --------------
        echo "collectd still isn't working, you can try and rerun the install script at some other time."
        echo "Or report this issue with the full 40 lines above."
        echo --------------
    fi
fi

if ! [[ -f /usr/share/graphs1090/noMalarky ]]; then
    bash $ipath/malarky.sh
fi

systemctl enable graphs1090
systemctl restart graphs1090

#fix readonly remount logic in fr24feed update script
sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null || true

echo --------------
echo --------------
echo "All done! Graphs available at http://$(ip route get 1.2.3.4 | grep -m1 -o -P 'src \K[0-9,.]*')/graphs1090"
echo "It may take up to 10 minutes until the first data is displayed"


if command -v nginx &>/dev/null
then
	echo --------------
	echo "To configure nginx for graphs1090, please add the following line(s) in the server {} section:"
	echo "include /usr/share/graphs1090/nginx-graphs1090.conf;"
fi

# curl -sL https://github.com/wiedehopf/graphs1090/raw/master/install.sh | bash

# install tar1090

