FROM lsiobase/alpine:3.7 as builder

RUN apk add --no-cache --virtual=build-dependencies \
	autoconf \
	automake \
	boost-dev \
	cmake \
	curl \
	file \
	g++ \
	geoip-dev \
	go \
	git \
	libtool \
	make

COPY Reflection /usr/lib/go/src/github.com/h31/Reflection

RUN	cd /usr/lib/go/src/github.com/h31/Reflection/; \
	go get .; \
	go build -o main -ldflags '-extldflags "-static"' .; \
	mv main /tmp/; \
	cd /tmp; \
	rm -rf /usr/lib/go/src/github.com/h31/Reflection/; \
	apk del --purge \
	build-dependencies

COPY services.d /etc/services.d
COPY --from=builder /tmp/main /tmp/main
RUN chmod +x /tmp/main

FROM alpine:latest AS builder

COPY libtorrent-rasterbar libtorrent-rasterbar

RUN cd libtorrent-rasterbar && \
    apk add --no-cache make cmake g++ boost-dev openssl-dev && \
    cmake -DCMAKE_INSTALL_LIBDIR=lib . && \
    make -j`nproc` && \
    make install && \
    strip /usr/local/lib/libtorrent-rasterbar.so.1.2.2

COPY qbittorrent qbittorrent

RUN cd qbittorrent && \
    apk add --no-cache qt5-qttools-dev && \
    ./configure --disable-gui && \
    make -j`nproc` && \
    make install

FROM alpine:latest

#COPY --from=builder /usr/local/lib/libtorrent-rasterbar.so.2.0.0 /usr/lib/libtorrent-rasterbar.so.10
COPY --from=builder /usr/local/lib/libtorrent-rasterbar.so.1.2.2 /usr/lib/libtorrent-rasterbar.so.10

COPY --from=builder /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache qt5-qtbase shadow

ENV WEBUI_PORT="8080" CHUID=1026 CHGID=100

EXPOSE 6881 6881/udp 8080

VOLUME /config /downloads

ENTRYPOINT ["/entrypoint.sh"]
