FROM technitium/dns-server:15.6.2@sha256:eb48ac5c135f4ab936b536f74f853d53e15ab39ef37fdbc9598a089b90d9f245
RUN apt-get update \
 && apt-get install -y --no-install-recommends udhcpc iproute2 \
 && rm -rf /var/lib/apt/lists/*
COPY network/udhcpc.script /etc/udhcpc/lab.script
COPY network/dhcp.sh /usr/local/bin/lab-dhcp
RUN sed -i 's/\r$//' /etc/udhcpc/lab.script /usr/local/bin/lab-dhcp \
 && chmod +x /etc/udhcpc/lab.script /usr/local/bin/lab-dhcp
ENTRYPOINT ["/usr/local/bin/lab-dhcp", "/usr/bin/dotnet", "/opt/technitium/dns/DnsServerApp.dll"]
CMD ["/etc/dns"]
