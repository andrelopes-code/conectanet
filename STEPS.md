# samba-ad-dc

### Alterar o hostname

```bash
sudo hostnamectl set-hostname [hostname]
```

### Alterar o hosts

```bash
127.0.0.1   localhost
127.0.1.1   [HOST]
[ipaddress] [FQDN]
```
```bash
# verificar
hostname -f
ping [FQDN]
```

# Desabilidar o dns-resolver

```bash
sudo systemctl disable --now systemd-resolved
sudo unlink /etc/resolv.conf
sudo touch /etc/resolv.conf
sudo vi /etc/resolv.conf
```
```bash
# IP do servidor samba
nameserver [ipaddress]

# fallback resolver
nameserver 8.8.8.8

# dominio principal para o samba
search [domain]
```
```bash
# Atributo de imutavel
sudo chattr +i /etc/resolv.conf
```

### Dependencias

```bash
sudo apt install libparse-yapp-perl cups-common libattr1-dev libjson-perl liblmdb-dev net-tools docbook-xml python-all-dev libbsd-dev libgpgme-dev libpopt-dev gdb libgnutls28-dev cups-core-drivers nfs-kernel-server autoconf libgnutls-dev libncurses5-dev libldap2-dev samba-dbg samba-dsdb-modules zlib1g python-dnspython samba-vfs-modules attr python3-markdown python3-dev winbind cups python3 python-dbg libpam-krb5 libpam0g-dev bison python3-gpgme zlib1g-dev dnsutils perl-modules nettle-dev libcap-dev libreadline-dev libacl1-dev smbclient docbook-xsl python-crypto lmdb-utils krb5-user python-gpgme libaio-dev libarchive-dev python3-dnspython xsltproc gnutls-bin cifs-utils samba-testsuite python-dev build-essential samba libjansson-dev perl nmap pkg-config samba-common krb5-config attr flex libparse-yapp-perl libblkid-dev acl libcups2-dev libnss-winbind debhelper python-markdown bind9utils libpam-winbind
```

```bash
# KRB5 REALM
[DOMAIN UPPERCASE]
# SERVERS FOR REALM
[FQDN]
# ADM SERVER FOR REALM
[FQDN]
```
### Desabilitar serviços

```bash
sudo systemctl disable --now smbd nmbd winbind
```

### Domain Provision
```bash
sudo systemctl unmask samba-ad-dc
sudo systemctl enable samba-ad-dc
```
```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
```
```bash
sudo samba-tool domain provision --use-rfc2307 --use-xattrs=yes --interactive
```
```bash
sudo mv /etc/krb5.conf /etc/krb5.conf.bak
sudo mv /var/lib/samba/private/krb5.conf /etc/krb5.conf
```
```bash
sudo systemctl start samba-ad-dc
sudo systemctl status samba-ad-dc
```

```bash
# verify
host -t A [DOMAIN]
```
