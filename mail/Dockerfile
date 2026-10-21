FROM ghcr.io/docker-mailserver/docker-mailserver:16.0.1@sha256:d0fe7668defe157aad57ea31b1707ad1e2fb57d7a91bdf17cbdf876549946c86
RUN apt-get update \
 && apt-get install -y --no-install-recommends udhcpc iproute2 \
 && rm -rf /var/lib/apt/lists/*
COPY network/udhcpc.script /etc/udhcpc/lab.script
COPY network/dhcp.sh /usr/local/bin/lab-dhcp
RUN sed -i 's/\r$//' /etc/udhcpc/lab.script /usr/local/bin/lab-dhcp \
 && chmod +x /etc/udhcpc/lab.script /usr/local/bin/lab-dhcp
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/lab-dhcp"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
