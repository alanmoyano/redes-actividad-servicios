#!/bin/sh
# Configura los servicios después de "docker compose up -d":
#   1. Zona DNS "redes.lab" en Technitium (vía su API HTTP)
#   2. Cuentas de correo en docker-mailserver
# También se puede hacer a mano desde el panel web: http://localhost:5380
set -eu
# Se puede ejecutar desde cualquier directorio, también con sh en Git Bash/WSL.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
# Lee valores literales de .env. Las variables exportadas tienen prioridad.
if [ -f .env ]; then
  DNS_PANEL_PORT=${DNS_PANEL_PORT:-$(sed -n 's/\r$//; s/^DNS_PANEL_PORT=//p' .env | tail -n 1)}
  DNS_ADMIN_PASSWORD=${DNS_ADMIN_PASSWORD:-$(sed -n 's/\r$//; s/^DNS_ADMIN_PASSWORD=//p' .env | tail -n 1)}
fi
API="http://localhost:${DNS_PANEL_PORT:-5380}/api"
DNS_ADMIN_PASSWORD=${DNS_ADMIN_PASSWORD:-admin}
ZONA=redes.lab

echo "== DNS: esperando a Technitium..."
login() {
  curl -fsS --connect-timeout 2 --max-time 2 --get "$API/user/login" --data-urlencode user=admin \
    --data-urlencode "pass=$DNS_ADMIN_PASSWORD"
}
intentos=0
until RESPUESTA=$(login 2>/dev/null) && echo "$RESPUESTA" | grep -q '"status":"ok"'; do
  intentos=$((intentos + 1))
  if [ "$intentos" -ge 15 ]; then
    echo "No se pudo iniciar sesión en $API. Revisá el servicio y DNS_ADMIN_PASSWORD." >&2
    exit 1
  fi
  sleep 2
done
TOKEN=$(echo "$RESPUESTA" | sed -E 's/.*"token":"([^"]+)".*/\1/')

api() { # api <endpoint> <parámetros>
  r=$(curl -s "$API/$1?token=$TOKEN&$2")
  echo "$r" | grep -q '"status":"ok"' || echo "   aviso: $1 $2 -> $r"
}

echo "== DNS: creando zona primaria $ZONA"
api zones/create "zone=$ZONA&type=Primary"

# Registros A (con su PTR en la zona inversa 10.10.10.in-addr.arpa)
for par in dns:10.10.10.10 dhcp:10.10.10.11 mail:10.10.10.12 gateway:10.10.10.1 cliente2:10.10.10.200; do
  nombre=${par%%:*}; ip=${par#*:}
  echo "   A    $nombre.$ZONA -> $ip"
  api zones/records/add "zone=$ZONA&domain=$nombre.$ZONA&type=A&ttl=300&ipAddress=$ip&ptr=true&createPtrZone=true&overwrite=true"
done

echo "   CNAME smtp/imap/webmail.$ZONA -> mail.$ZONA"
api zones/records/add "zone=$ZONA&domain=smtp.$ZONA&type=CNAME&ttl=300&cname=mail.$ZONA&overwrite=true"
api zones/records/add "zone=$ZONA&domain=imap.$ZONA&type=CNAME&ttl=300&cname=mail.$ZONA&overwrite=true"
api zones/records/add "zone=$ZONA&domain=webmail.$ZONA&type=CNAME&ttl=300&cname=mail.$ZONA&overwrite=true"
echo "   MX   $ZONA -> mail.$ZONA (prioridad 10)"
api zones/records/add "zone=$ZONA&domain=$ZONA&type=MX&ttl=300&exchange=mail.$ZONA&preference=10&overwrite=true"

echo "== Correo: creando cuentas (usuario = contraseña)"
for u in alumno1 alumno2 profe; do
  if grep -q "^$u@$ZONA|" mail/config/postfix-accounts.cf 2>/dev/null; then
    echo "   $u@$ZONA ya existe"
  else
    docker compose exec -T mail setup email add "$u@$ZONA" "$u" && echo "   $u@$ZONA creada"
  fi
done
docker compose exec -T mail setup alias add "postmaster@$ZONA" "profe@$ZONA" 2>/dev/null || true

echo "== Listo"
