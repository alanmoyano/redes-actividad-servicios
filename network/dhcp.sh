#!/bin/sh
set -eu
IFACE=${DHCP_INTERFACE:-eth0}
echo "[dhcp] IP inicial de Docker: $(ip -4 -o addr show dev "$IFACE" | awk '{print $4}')"
# Espera una concesión antes de iniciar el servicio. Luego udhcpc queda en
# background para renovar; si no hay respuesta, el contenedor falla y se ve en logs.
# docker-mailserver borra *.pid de /run al arrancar; usamos un nombre sin esa extensión.
udhcpc -i "$IFACE" -s /etc/udhcpc/lab.script -p /run/lab-udhcpc \
  -x "hostname:$(hostname)" -n -t 10 -T 2
exec "$@"
