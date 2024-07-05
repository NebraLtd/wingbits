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

# install graphs1090
repo="https://github.com/wiedehopf/graphs1090"
ipath=/usr/share/graphs1090

mkdir -p /usr/share/graphs1090/installed
mkdir -p /var/lib/graphs1090/scatter
mkdir -p /run/graphs1090

apt install --no-install-recommends --no-install-suggests -y \
    rrdtool unzip bash-builtins collectd-core libpython3.9
cd /tmp
wget --timeout=30 -q -O /tmp/master.zip https://github.com/wiedehopf/graphs1090/archive/master.zip
unzip -q -o master.zip
cd /tmp/graphs1090-master

mkdir -p /var/lib/collectd/rrd/localhost/dump1090-localhost

cp dump1090.db dump1090.py system_stats.py LICENSE /usr/share/graphs1090
cp *.sh /usr/share/graphs1090
cp malarky.conf /usr/share/graphs1090
chmod u+x /usr/share/graphs1090/*.sh
cp /etc/collectd/collectd.conf /etc/collectd/collectd.conf.graphs1090 &>/dev/null || true
cp collectd.conf /etc/collectd/collectd.conf

sed -i -e 's/RRATimespan 96048000/\0\nRRATimespan 576288000/' /etc/collectd/collectd.conf
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
cp -r html /usr/share/graphs1090
cp default /etc/default/graphs1090
cp default /usr/share/graphs1090/default-config
cp collectd.conf /usr/share/graphs1090/default-collectd.conf
cp service.service /lib/systemd/system/graphs1090.service
cp nginx-graphs1090.conf /usr/share/graphs1090

echo "------------------"
echo "TEST 1"
echo "------------------"

if [ -d /etc/lighttpd/conf.d/ ] && ! [ -d /etc/lighttpd/conf-enabled/ ] && ! [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null
then
    ln -snf /etc/lighttpd/conf.d /etc/lighttpd/conf-enabled
    mkdir -p /etc/lighttpd/conf-available
fi
if [ -d /etc/lighttpd/conf-enabled/ ] && [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null
then
    lighttpd=yes
fi

echo "------------------"
echo "TEST 2"
echo "------------------"

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

echo "------------------"
echo "TEST 3"
echo "------------------"

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

echo "------------------"
echo "TEST 4"
echo "------------------"

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

echo "------------------"
echo "TEST 5"
echo "------------------"


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

echo "------------------"
echo "TEST 6"
echo "------------------"

if ! [[ -f /usr/share/graphs1090/noMalarky ]]; then
    bash $ipath/malarky.sh
fi

# Cleanup
rm -Rf /tmp/graphs1090-master
rm -Rf /tmp/master.zip
