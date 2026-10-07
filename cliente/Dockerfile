FROM alpine:3.22
# udhcpc (cliente DHCP) viene en busybox; el resto son herramientas de prueba
RUN apk add --no-cache bind-tools iproute2 iputils curl mutt \
    busybox-extras netcat-openbsd tcpdump
COPY udhcpc.script /etc/udhcpc/lab.script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /etc/udhcpc/lab.script /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
