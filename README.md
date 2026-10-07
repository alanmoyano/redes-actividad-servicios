# Actividad Integradora VI – Laboratorio de servicios de red en Docker

Red virtual con tres servidores (DHCP, DNS y correo con webmail) y dos equipos cliente, todo en contenedores.

```
                    Red "lan" 10.10.10.0/24 (bridge de Docker)
 ┌──────────────┬──────────────┬───────────────┬────────────────┬────────────────┐
 │ dns          │ dhcp         │ mail          │ cliente1       │ cliente2       │
 │ 10.10.10.10  │ 10.10.10.11  │ 10.10.10.12   │ DHCP (pool)    │ DHCP (reserva) │
 │ Technitium   │ ISC Kea      │ Postfix +     │ 10.10.10.100.. │ 10.10.10.200   │
 │ DNS Server   │ DHCPv4       │ Dovecot +     │                │                │
 │              │              │ Roundcube     │                │                │
 └──────────────┴──────────────┴───────────────┴────────────────┴────────────────┘
   gateway 10.10.10.1 (salida a Internet)       dominio: redes.lab
```

Roundcube corre en su propio contenedor (`webmail`), pero comparte la interfaz de red de `mail`.
Por eso `http://mail.redes.lab` responde con el webmail, y éste se conecta a Postfix y Dovecot por `localhost`.

## Software utilizado

| Servicio | Servidor | Cliente | Puerto(s) | ¿Puerto por defecto? |
|---|---|---|---|---|
| DHCP | ISC Kea DHCPv4 2.6 (`dhcp/kea-dhcp4.conf`) | `udhcpc` (BusyBox) | 67/UDP servidor, 68/UDP cliente | Sí |
| DNS | Technitium DNS Server | `dig`, `ping`, resolver del sistema | 53/UDP y TCP | Sí |
| Panel web del DNS | Technitium (web console) | Navegador web | 80/TCP | **No**: por defecto es 5380; se cambió a 80 para entrar por `http://dns.redes.lab` |
| Correo – envío | Postfix (docker-mailserver) | `mutt`, Thunderbird | 587/TCP (Submission), 25/TCP entre servidores | Sí |
| Correo – lectura | Dovecot (docker-mailserver) | `mutt`, `curl`, Thunderbird | 143/TCP (IMAP) | Sí |
| Webmail | Roundcube (Apache + PHP) | Navegador web | 80/TCP (HTTP); 8080 en la Mac para la LAN | Sí (80) dentro de la red |

## Puesta en marcha

```sh
docker compose up -d --build      # levanta servidores y clientes
./scripts/setup.sh                # crea la zona DNS y las cuentas de correo
```

> La primera vez, los clientes pueden arrancar antes de que existan la zona DNS y las cuentas.
> Si pasa eso, reinicialos: `docker compose restart cliente1 cliente2`.

| Sitio | Con el DNS del laboratorio | Sin cambiar el DNS |
|---|---|---|
| Panel de Technitium (`admin` / `admin`) | <http://dns.redes.lab> | <http://localhost:5380> o <http://10.10.10.10> |
| Webmail Roundcube | <http://mail.redes.lab> | <http://localhost> o <http://10.10.10.12> |

Para usar los nombres, ver [Usar el DNS del laboratorio desde tu computadora](#usar-el-dns-del-laboratorio-desde-tu-computadora).

Cuentas de correo (la contraseña es igual al usuario): `alumno1@redes.lab`, `alumno2@redes.lab`, `profe@redes.lab`.

## Demostraciones (para el video)

### DHCP

```sh
docker logs cliente1                     # DISCOVER → OFFER → REQUEST → ACK
docker logs dhcp | grep -E "DHCP4_LEASE" # el servidor registrando las concesiones
docker exec dhcp cat /var/lib/kea/dhcp4.leases

# Renovar la IP en vivo (captura los paquetes DORA con tcpdump en otra terminal):
docker exec -it cliente1 tcpdump -ni eth0 port 67 or port 68
docker exec cliente1 sh -c 'kill $(pidof udhcpc); udhcpc -i eth0 -s /etc/udhcpc/lab.script -q'
```

- Pool dinámico: `10.10.10.100 – 10.10.10.150`, concesión de 1 hora.
- Concesiones persistentes: Kea las guarda en `dhcp/leases/dhcp4.leases` (CSV, se puede abrir en el editor).
  Tras un `docker compose down` / `up`, el servidor recuerda a quién le dio cada IP, como exige [RFC 2131](https://www.rfc-editor.org/rfc/rfc2131#section-3.1).
  `cliente1` tiene MAC fija (`02:42:0a:0a:00:64`) para que el servidor lo reconozca al recrearse, y por eso recibe la misma IP.
- Reserva por MAC: `cliente2` (`02:42:0a:0a:00:c8`) siempre recibe `10.10.10.200`.
- Opciones entregadas: gateway `10.10.10.1`, DNS `10.10.10.10`, dominio `redes.lab`.

### DNS

```sh
docker exec -it cliente1 sh
  cat /etc/resolv.conf        # el DNS lo recibió por DHCP
  dig mail.redes.lab          # registro A
  dig MX redes.lab            # registro MX
  dig -x 10.10.10.12          # resolución inversa (PTR)
  dig smtp.redes.lab          # CNAME
  ping dhcp                   # nombre corto gracias a "search redes.lab"
  dig google.com              # recursión hacia Internet (forwarders 1.1.1.1 / 8.8.8.8)
```

Desde la computadora anfitriona también se puede consultar: `dig @10.10.10.10 mail.redes.lab` (o `nslookup mail.redes.lab 10.10.10.10` en Windows).

### Correo

```sh
# cliente1 (alumno1) envía un mail a alumno2
docker exec -it cliente1 mutt              # interactivo: "m" para redactar
docker exec cliente1 sh -c 'echo "Hola!" | mutt -s "Prueba" alumno2@redes.lab'

# cliente2 (alumno2) lee su bandeja
docker exec -it cliente2 mutt

# Ver la transacción en el servidor
docker logs -f mail
```

### Webmail (Roundcube)

1. Abrí <http://mail.redes.lab> (o <http://localhost>) e ingresá con `alumno1` / `alumno1` (no hace falta escribir `@redes.lab`).
2. Redactar → destinatario `alumno2@redes.lab` → Enviar.
3. Cerrá sesión, entrá como `alumno2` y el mensaje aparece en *Entrada*.
4. En paralelo, `docker logs -f mail` muestra a Postfix autenticando a `alumno1` y entregando el mensaje a Dovecot.

### SMTP "a mano" con telnet (muestra el protocolo):

```sh
docker exec -it cliente1 telnet mail.redes.lab 25
  EHLO cliente1
  MAIL FROM:<alumno1@redes.lab>
  RCPT TO:<alumno2@redes.lab>
  DATA
  Subject: hola por telnet

  cuerpo del mensaje
  .
  QUIT
```

**Thunderbird en la Mac:** OrbStack permite llegar a las IPs de los contenedores desde la Mac.
Configurá la cuenta a mano con IMAP `10.10.10.12:143` y SMTP `10.10.10.12:587`, sin cifrado y con contraseña normal.

## Usar el DNS del laboratorio desde tu computadora

Cualquier persona que levante esta red con `docker compose up -d` puede abrir `http://mail.redes.lab` y `http://dns.redes.lab` en su navegador.
Sólo tiene que configurar **`10.10.10.10`** como servidor DNS en los ajustes de red de su sistema operativo:

- **macOS:** Ajustes del Sistema → Red → (WiFi o Ethernet) → Detalles → DNS → `+` → `10.10.10.10`.
- **Windows:** Configuración → Red e Internet → (adaptador) → Asignación de servidor DNS → Editar → Manual → IPv4 → DNS preferido `10.10.10.10`.
- **Linux (GNOME):** Configuración → Red → (conexión) → IPv4 → DNS: desactivar "Automático" y poner `10.10.10.10`.

No hace falta tocar archivos del sistema. Así funciona:

1. El navegador le pregunta a Technitium por `mail.redes.lab`, y Technitium responde `10.10.10.12` porque es el servidor autoritativo de la zona `redes.lab`.
2. Para cualquier otro dominio (`google.com`, etc.), Technitium hace de **resolver recursivo** y le consulta a `1.1.1.1` y `8.8.8.8`. Internet sigue funcionando con normalidad.

**Requisito: la computadora tiene que poder llegar a la red `10.10.10.0/24`.**

| Entorno | ¿Llega a `10.10.10.x`? |
|---|---|
| Linux con Docker Engine | Sí, el bridge de Docker es una interfaz del propio equipo. |
| macOS con OrbStack | Sí, OrbStack enruta las IPs de los contenedores hacia la Mac. |
| macOS / Windows con Docker Desktop | **No**: los contenedores viven en una VM cuya red no se expone. Habría que usar OrbStack (macOS) o WSL2 con Docker Engine (Windows). |

> **Importante:** mientras el DNS de la computadora sea `10.10.10.10`, toda la resolución de nombres depende de que el contenedor `dns` esté levantado.
> Al terminar, o si se apaga Docker, volvé el DNS a "Automático" o vas a quedarte sin Internet "por nombre".

### Desde otra computadora de la misma red WiFi/LAN

Otra computadora no ve la red `10.10.10.0/24`, que vive dentro del equipo que corre Docker.
Sí ve la IP de ese equipo en la LAN (por ejemplo `192.168.0.28`; en macOS se consulta con `ipconfig getifaddr en0`), donde el webmail está publicado en el puerto **8080**:

- Directo por IP: `http://192.168.0.28:8080`.
- Por nombre: agregar en el archivo *hosts* la línea `192.168.0.28  mail.redes.lab` y abrir `http://mail.redes.lab:8080`.
  - El archivo es `/etc/hosts` en Mac y Linux, y `C:\Windows\System32\drivers\etc\hosts` en Windows.
- Se usa el 8080 porque OrbStack sólo expone los puertos menores a 1024, como el 80, en `localhost`.

## Archivos

- `docker-compose.yml`: topología, IPs y variables de cada servicio.
- `dhcp/kea-dhcp4.conf`: pool, reserva y opciones DHCP.
- `dhcp/leases/`: base de concesiones de Kea (la escribe el servidor; no editar a mano con el servicio corriendo).
- `cliente/`: imagen de los equipos cliente (`udhcpc`, `dig`, `mutt`, `tcpdump`, `telnet`).
- `mail/config/`: cuentas y ajustes de Postfix/Dovecot. Habilita autenticación **sin TLS**, sólo para el laboratorio.
- `webmail/config.inc.php`: ajustes de Roundcube (idioma, dominio por defecto, autenticación SMTP).
- `scripts/setup.sh`: crea la zona `redes.lab` en Technitium por API y las cuentas de correo.

## Agregar más clientes

Copiá el bloque `cliente1` en `docker-compose.yml` con otro nombre (`cliente3`, …) y ejecutá `docker compose up -d cliente3`.

## Reiniciar todo de cero

```sh
docker compose down -v && rm -f mail/config/postfix-accounts.cf mail/config/postfix-virtual.cf
```
