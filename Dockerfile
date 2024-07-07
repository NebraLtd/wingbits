# Docker Container that runs the Wingbits

ARG BUILD_BOARD

####################################################################################################
################################## Stage: builder ##################################################
FROM balenalib/"$BUILD_BOARD"-debian-python:bullseye-build-20230530 AS builder

ARG READSB_COMMIT=4f7a7f18c5f88ed57145c04038a04a10d48f8638
ARG TEMP_INSTALL="git libusb-1.0-0-dev libncurses-dev build-essential librtlsdr-dev debhelper zlib1g-dev libzstd-dev pkg-config libzstd1"
ARG PERM_INSTALL="wget curl gettext-base tini ncurses-bin zlib1g lighttpd gettext-base libusb-1.0-0 librtlsdr0 rtl-sdr libncurses6 jq"

WORKDIR /tmp

RUN apt update && \
	apt install -y $TEMP_INSTALL $PERM_INSTALL

WORKDIR /tmp
    
RUN git clone --single-branch https://github.com/wiedehopf/readsb && \
	cd readsb && \
	git checkout $READSB_COMMIT && \
	make AIRCRAFT_HASH_BITS=14 RTLSDR=yes

# No need to cleanup the builder

####################################################################################################
################################### Stage: runner ##################################################
FROM alpine:3.20 AS runner

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

ARG PERM_INSTALL="wget curl gettext-base tini ncurses-bin zlib1g lighttpd gettext-base libusb-1.0-0 librtlsdr0 rtl-sdr libncurses6 jq"

RUN apk update && \
	apk add --no-cache $PERM_INSTALL

COPY wingbits_installer.sh /tmp
COPY start.sh /
COPY --from=builder /tmp/readsb/readsb /usr/bin/feed-wingbits

WORKDIR /tmp
 
RUN chmod +x /tmp/wingbits_installer.sh && \
	./wingbits_installer.sh && \
	chmod +x /start.sh && \
	mkdir -p /run/wingbits-feed && \
        mkdir -p /run/readsb && \
	mkdir -p /etc/wingbits && \
	echo "$WINGBITS_CONFIG_VERSION" > /etc/wingbits/version && \
	rm -rf /tmp/*

RUN curl -o /etc/vector/vector.yaml https://gitlab.com/wingbits/config/-/raw/master/vector.yaml
RUN curl -0 /etc/default/tar1090 https://raw.githubusercontent.com/wiedehopf/tar1090/master/default
RUN sed -i 's|DEVICE_ID|WINGBITS_DEVICE_ID|g' /etc/vector/vector.yaml

RUN apt clean && apt autoclean && apt autoremove && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--", "/start.sh"]
