HOSTNAME="srv-cnet"
IP_ADDRESS="192.168.0.254"
DOMAIN="conectanet.lan"
INTERFACE_INTERNA="enp0s8"
NAMESERVERS="192.168.0.254 8.8.8.8 1.1.1.1"
BROADCAST="192.168.0.255"
NETWORK="192.168.0.0"
NETMASK="255.255.255.0"

DHCP_NAMESERVERS="192.168.0.254, 8.8.8.8, 1.1.1.1"
RANGE="192.168.0.10 192.168.0.230"
GATEWAY="192.168.0.254"

atualizar_sistema() {
  # Atualiza o sistema
  apt update > /dev/null
  apt upgrade -y > /dev/null
}
instalar_dependencias() {
  apt install build-essential libacl1-dev libattr1-dev libblkid-dev libgnutls-dev libreadline-dev python-dev libpam0g-dev python-dnspython gdb pkg-config libpopt-dev libldap2-dev dnsutils libbsd-dev docbook-xsl libcups2-dev nfs-kernel-server isc-dhcp-server -y

  apt install samba samba-common smbclient cifs-utils samba-vfs-modules samba-testsuite samba-dbg acl attr samba-dsdb-modules cups cups-common cups-core-drivers nmap winbind smbclient libnss-winbind libpam-winbind python3 -y

  apt install krb5-user krb5-config  -y
}
alterar_hosts() {
  sed -i "s/127\.0\.1\.1\t.*/127.0.1.1\t${HOSTNAME}\n${IP_ADDRESS}\t${HOSTNAME}.${DOMAIN}\t${HOSTNAME}/" /etc/hosts
}
alterar_hostname() {
  # Altera o hostname
  sed -i "s/.*/${HOSTNAME}/" /etc/hostname
  hostname -F /etc/hostname 
}
configurar_interface_de_rede() {
  sed -i -e "10a \
  auto ${INTERFACE_INTERNA}\n\
  iface ${INTERFACE_INTERNA} inet static\n\
  address ${IP_ADDRESS}\n\
  netmask ${NETMASK}\n\
  network ${NETWORK}\n\
  broadcast ${BROADCAST}\n\
  dns-nameservers ${NAMESERVERS}\n\
  dns-domain ${DOMAIN}\n\
  dns-search ${DOMAIN}" -e '11,$d' /etc/network/interfaces
  ifdown $INTERFACE_INTERNA
  ifup $INTERFACE_INTERNA 
}
configurar_dhcp() {
    apt install isc-dhcp-server
    {
        echo "# Configuração do serviço DHCP."
        echo "authoritative;"
        echo "subnet ${NETWORK} netmask ${NETMASK} {"
        echo "    range ${RANGE};"
        echo "    option domain-name-servers ${DHCP_NAMESERVERS};"
        echo "    option domain-name \"${HOSTNAME}.${DOMAIN}\";"
        echo "    option subnet-mask ${NETMASK};"
        echo "    option routers ${GATEWAY};"
        echo "    option broadcast-address ${BROADCAST};"
        echo "    default-lease-time 600;"
        echo "    max-lease-time 7200;"
        echo "}"
    } >> /etc/dhcp/dhcpd.conf
}
configurar_default() {
    # Configura o arquivo default/isc-dhcp-server
    sed -i "s/INTERFACES=\"\"/INTERFACES=\"${INTERFACE_INTERNA}\"/" /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
}
copiar_arquivos() {
    apt install sarg squid apache2

    cp servidor/firewall/firewall /usr/local/sbin/firewall
    chmod +x /usr/local/sbin/firewall

    cp servidor/proxy/sqd /usr/local/sbin/sqd
    chmod +x /usr/local/sbin/sqd

    cp access-denied/ERR_ACCESS_DENIED_data.html /usr/share/squid/errors/pt-br/ERR_ACCESS_DENIED

    cp servidor/proxy/squid.conf /etc/squid/squid.conf
    mkdir /etc/squid/files
    touch /etc/squid/files/negados.acl
    echo "fiemg.com.br" > negados.acl

    cp servidor/sarg/sarg.conf /etc/sarg/sarg.conf
}
pasta_cache_squid() {
    service squid stop
    mkdir /etc/squid/cache
    chmod 777 /etc/squid/cache
    squid -z
    service squid restart
}
inicializacao_firewall() {
    # Arquivo de inicialização do Firewall
    cp servidor/firewall/firewall.service /lib/systemd/system/firewall.service
    systemctl daemon-reload
    systemctl enable firewall.service
}
renomear_arquivo_smb() {
  mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
}
parar_servicos_necessarios() {
  systemctl disable --now smbd nmbd winbind systemd-resolved
  systemctl disable --now systemd-resolved
  unlink /etc/resolv.conf
  touch /etc/resolv.conf
  echo "# IP do servidor samba \
        nameserver ${IP_ADDRESS} \
        # fallback resolver \
        nameserver 8.8.8.8  \
        # dominio principal para o samba \
        search ${DOMAIN}"
  chattr +i /etc/resolv.conf
  systemctl unmask samba-ad-dc
  systemctl enable samba-ad-dc
}
provisionar_dominio() {
  samba-tool domain provision --use-rfc2307 --use-xattr=yes --interactive
}
mover_arquivo_krb() {
  mv /var/lib/samba/private/krb5.conf /etc/
}
iniciar_ativar_samba_ad_dc() {
  systemctl start samba-ad-dc
}

atualizar_sistema
instalar_dependencias
alterar_hosts
alterar_hostname
configurar_interface_de_rede
configurar_dhcp
configurar_default
copiar_arquivos
pasta_cache_squid
inicializacao_firewall
renomear_arquivo_smb
parar_servicos_necessarios
provisionar_dominio
mover_arquivo_krb
iniciar_ativar_samba_ad_dc