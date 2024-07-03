ARG BUILD_BOARD
ARG BUILD_ARCH

FROM balenalib/"$BUILD_BOARD"-debian-python:bullseye-build-20230530 AS base

EXPOSE 30154

ENV WINGBITS_DEVICE_ID=
ENV DUMP1090_DEVICE=0
ENV DUMP1090_GAIN=""
ENV DUMP1090_PPM=0
ENV DUMP1090_MAX_RANGE=360
ENV DUMP1090_ADAPTIVE_DYNAMIC_RANGE=""
ENV DUMP1090_ADAPTIVE_BURST=""
ENV DUMP1090_ADAPTIVE_MIN_GAIN=""
ENV DUMP1090_ADAPTIVE_MAX_GAIN=""
ENV DUMP1090_SLOW_CPU=""
ENV WINGBITS_CONFIG_VERSION=0.0.5

ARG PERM_INSTALL="curl gettext-base tini ncurses-bin zlib1g lighttpd gettext-base libusb-1.0-0 libbladerf2 libhackrf0 librtlsdr0 rtl-sdr libncurses6" 

RUN apt update && \
	apt install -y $PERM_INSTALL && \
	apt clean && apt autoclean && apt autoremove && \
	rm -rf /var/lib/apt/lists/*

FROM base AS buildstep

ARG READSB_BRANCH=d794155ba65796a76cd0a436f9709f4601509320
ARG TEMP_INSTALL="git gcc make libusb-1.0-0-dev ncurses-dev build-essential debhelper libncurses5-dev zlib1g-dev python3-dev libzstd-dev pkg-config"

WORKDIR /tmp

RUN apt update && \
	apt install -y $TEMP_INSTALL

WORKDIR /tmp

RUN apt install --no-install-recommends --no-install-suggests -y \
            git build-essential debhelper libusb-1.0-0-dev \
            librtlsdr-dev librtlsdr0 pkg-config \
            libncurses-dev zlib1g-dev zlib1g libzstd-dev libzstd1 && \
        git clone --depth 20 https://github.com/wiedehopf/readsb.git && \
        cd readsb && \
        export DEB_BUILD_OPTIONS=noddebs && \
        dpkg-buildpackage -b -Prtlsdr -ui -uc -us && \
        sudo dpkg -i ../readsb_*.deb

FROM base AS release

COPY wingbits_installer.sh /tmp
COPY start.sh /
COPY --from=buildstep /tmp/readsb/readsb /usr/bin/feed-wingbits

WORKDIR /tmp

RUN chmod +x /tmp/wingbits_installer.sh && \
	./wingbits_installer.sh && \
	chmod +x /start.sh && \
	mkdir -p /run/wingbits-feed && \
	mkdir -p /etc/wingbits && \
	echo "$WINGBITS_CONFIG_VERSION" > /etc/wingbits/version && \
	rm -rf /tmp/*

#COPY vector.yaml /etc/vector/vector.yaml
RUN curl -o /etc/vector/vector.yaml https://gitlab.com/wingbits/config/-/raw/$WINGBITS_CONFIG_VERSION/vector.yaml
RUN sed -i 's|DEVICE_ID|WINGBITS_DEVICE_ID|g' /etc/vector/vector.yaml

ENTRYPOINT ["/usr/bin/tini", "--", "/start.sh"]
