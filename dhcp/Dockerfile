FROM alpine:3.22
RUN apk add --no-cache kea-dhcp4 \
 && mkdir -p /run/kea /var/lib/kea
EXPOSE 67/udp
CMD ["kea-dhcp4", "-c", "/etc/kea/kea-dhcp4.conf"]
