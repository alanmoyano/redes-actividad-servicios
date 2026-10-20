#!/bin/sh
set -e

# 1. Configuración de mutt (cliente de correo) para el usuario de este equipo
if [ -n "$MAIL_USER" ]; then
  cat > /root/.muttrc <<MUTT
set realname   = "$(hostname)"
set from       = "$MAIL_USER"
set imap_user  = "$MAIL_USER"
set imap_pass  = "$MAIL_PASS"
set folder     = "imap://mail.redes.lab:143/"
set spoolfile  = "+INBOX"
set smtp_url   = "smtp://$MAIL_USER@mail.redes.lab:587/"
set smtp_pass  = "$MAIL_PASS"
set ssl_starttls = no
set ssl_force_tls = no
set use_from   = yes
set record     = ""
MUTT
fi

# 2. Aplica DHCP antes de ejecutar el comando del contenedor.
exec /usr/local/bin/lab-dhcp "$@"
