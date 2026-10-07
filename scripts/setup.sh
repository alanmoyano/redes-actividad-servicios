#!/bin/sh
# Configura los servicios después de "docker compose up -d":
#   1. Zona DNS "redes.lab" en Technitium (vía su API HTTP)
#   2. Cuentas de correo en docker-mailserver
# También se puede hacer a mano desde el panel web: http://localhost:5380
set -e
API=http://localhost:5380/api
ZONA=redes.lab

echo "== DNS: esperando a Technitium..."
until curl -sf "$API/user/login?user=admin&pass=admin" >/dev/null; do sleep 2; done
TOKEN=$(curl -s "$API/user/login?user=admin&pass=admin" | sed -E 's/.*"token":"([^"]+)".*/\1/')

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
    docker exec mail setup email add "$u@$ZONA" "$u" && echo "   $u@$ZONA creada"
  fi
done
docker exec mail setup alias add "postmaster@$ZONA" "profe@$ZONA" 2>/dev/null || true

echo "== Listo"
