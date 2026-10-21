FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f
# udhcpc de Debian usa glibc; las demás herramientas sirven para las pruebas del laboratorio.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      udhcpc bind9-dnsutils iproute2 iputils-ping ca-certificates curl mutt \
      inetutils-telnet netcat-openbsd tcpdump \
 && rm -rf /var/lib/apt/lists/*
COPY network/udhcpc.script /etc/udhcpc/lab.script
COPY cliente/entrypoint.sh /entrypoint.sh
COPY network/dhcp.sh /usr/local/bin/lab-dhcp
# Tolera checkouts de Windows con CRLF, incluso sin atributos de Git aplicados.
RUN sed -i 's/\r$//' /etc/udhcpc/lab.script /entrypoint.sh /usr/local/bin/lab-dhcp \
 && chmod +x /etc/udhcpc/lab.script /entrypoint.sh /usr/local/bin/lab-dhcp
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
