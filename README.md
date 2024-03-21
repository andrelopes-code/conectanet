# ConectaNet

<br>

<br>

## Configuração Básica

> Este documento fornece uma visão geral das configurações e serviços implementados no servidor, incluindo firewall, proxy, DHCP e Active Directory. Esperamos que esta documentação seja útil para administradores de sistemas e equipe de suporte de TI na gestão eficaz do ambiente de servidores da ConectaNet.

### Informações da Máquina
- **Nome da máquina:**      srv-cnet
- **Sistema operacional:**  ubuntu server 16.04 LTS
- **Nome de usuário:**      conectanet
- **Senha:**                ConectaNet@2023.2

### Configuração de Rede
- **Endereço da rede:**     192.168.0.0/24
- **Endereço do servidor:** 192.168.0.254
- **Interfaces de rede:**   eno1, enp2s0
- **Domínio:**              conectanet.lan

### Serviços e Aplicativos Instalados
- **Firewall:**             Utilizamos o iptables para garantir a segurança do servidor e controlar o tráfego de rede.
- **Proxy:**                O servidor squid atua como proxy, melhorando o desempenho e a segurança das conexões à internet.
- **DHCP:**                 Utilizamos o isc-dhcp-server para gerenciar a atribuição dinâmica de endereços IP na nossa rede local.
- **AD:**                   Configuramos o samba-ad-dc para autenticação centralizada e gerenciamento de usuários.

<br>

### Atualização dos pacotes do sistema
Para garantir que o sistema esteja atualizado, execute os seguintes comandos:
```bash
sudo apt update
sudo apt upgrade -y
```

<br>

### Configuração do arquivo `/etc/hosts`
Edite o arquivo `/etc/hosts` com o seguinte conteúdo:
```bash
sudo vi /etc/hosts
```

#### Conteúdo do arquivo:
```bash
127.0.0.1       localhost
192.168.0.254   srv-cnet.conectanet.lan srv-cnet
```

<br>

### Configuração das interfaces de rede
Edite o arquivo `/etc/network/interfaces` com o seguinte conteúdo:
```bash
sudo vi /etc/network/interfaces
```

#### Conteúdo do arquivo:
```bash
# Interface de rede externa
auto eno1
iface eno1 inet dhcp

# Interface de rede interna
auto enp2s0
iface enp2s0 inet static
        address 192.168.0.254
        netmask 255.255.255.0
        network 192.168.0.0
        broadcast 192.168.0.255
        dns-nameservers 192.168.0.254 8.8.8.8 1.1.1.1
        dns-search conectanet.lan
        dns-domain conectanet.lan
```

#### Reinicie a interface de rede
```bash
sudo ifup enp2s0
sudo systemctl restart networking
```

<br>

### Configuração manual de resolução de DNS
```bash
sudo systemctl disable --now systemd-resolved
sudo unlink /etc/resolv.conf
sudo vi /etc/resolv.conf
```

#### Conteúdo do arquivo:

```bash
# Endereço do controlador de domínio Samba
nameserver 192.168.0.254
# Endereço de fallback
nameserver 8.8.8.8
# Domínio de pesquisa para resolução de nomes
search conectanet.lan
```

#### Adicione o atributo de imutabilidade:

```bash
sudo chattr +i /etc/resolv.conf
```

<br><br>

## Firewall Iptables

### Arquivo de script das regras do firewall (Iptables)

#### conteúdo do arquivo `firewall`:
```bash

```

#### Tornar o script um executavel
```bash
sudo chmod +x firewall
```

#### Mover o script para uma pasta do $PATH
```bash
sudo mv firewall /usr/local/sbin
```

#### Criar o arquivo de serviço para inicialização automática
```bash
sudo vi /lib/systemd/system/firewall.service
```

#### conteúdo do arquivo:
```bash
[Unit]
Description=Inicializa o script firewall automaticamente.
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/firewall start
ExecStop=/usr/local/sbin/firewall stop
RemainAfterExit=true
KillMode=process
```

#### Recarregar daemons do sistema
```bash
sudo systemctl daemon-reload
```

#### Ativar o serviço do firewall
```bash
sudo systemctl enable firewall.service
```

<br><br>

## Proxy Squid

### Instalar o `squid3` e `apache2`
```bash
sudo apt install squid3 apache2
```

<br>

### Configuração do `squid`
```bash
sudo vi /etc/squid/squid.conf
```

#### conteúdo do arquivo:
```bash
#==  ACL's padrao  ==========================================================#
acl SSL_ports port 443 563 873                                                       
acl Safe_ports port 80 21 443 70 210 280 488 445 139 591 777 8080 3128               
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

#============================================================================#

# Diretorio de erros PT|BR
error_directory /usr/share/squid/errors/pt-br
access_log /var/log/squid/access.log

# Configuracao de cache de memoria de disco
cache_mem 2500 MB
maximum_object_size_in_memory 1 MB
cache_log /var/log/squid/cache.log

# Definicoes de cache no disco
maximum_object_size 25 MB
maximum_object_size 1 KB
cache_dir ufs /etc/squid/cache 15360 16 128

# Substituicao do cache
cache_swap_low 80
cache_swap_high 90

# Sarg
acl sarg dst 192.168.0.254
http_access allow sarg

#==  ACL's  =================================================================#

acl localnet src 192.168.0.0/24
acl negados url_regex -i "/etc/squid/files/negados.acl"

#==  DEFAULT HTTP-ACCESS  ===================================================#

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost

#==  HTTP-ACCESS  ===========================================================#

# Permite conexão da rede local, menos para os dominios proibidos
http_access allow localnet !negados

#==  DENY ALL  ==============================================================#

http_access deny all

visible_hostname proxy_server
http_port 192.168.0.254:3128

#============================================================================#

coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern .               0       20%     4320
```

#### Pasta de cache do `squid`
```bash
# Criar a pasta cache
sudo mkdir /etc/squid/cache
# Dar permissão total
sudo chmod 777 /etc/squid/cache
# Parar o Squid
sudo service squid stop
# criar o banco de dados de cache do Squid
sudo squid -z
# Reinicia o Squid
```

#### Página de Acesso Negado
```bash
sudo vi /usr/share/squid/errors/pt-br/ERR_ACCESS_DENIED
```
conteúdo do arquivo:
```html
# arquivo html da pagina de acesso negado.
```

#### Criar pasta `files` e arquivo `negados.acl`
```bash
sudo mkdir /etc/squid/files
sudo touch /etc/squid/files/negados.acl
```

#### Reiniciar o `squid`
```bash
sudo service squid restart
```

<br><br>

## Sarg
### Instalar o Sarg
```bash
sudo apt install sarg
```

<br>

### Configuração do `sarg`
```bash
sudo vi /etc/sarg/sarg.conf
```
#### conteúdo do arquivo:
```bash
# Localização do arquivo de log de acesso do Squid
access_log /var/log/squid/access.log
# Título da página de relatórios
title "Logs de acesso do Squid"
# Fonte para o texto
font_face Tahoma,Verdana,Arial
# Cor do cabeçalho
header_color #000
# Cor de fundo do cabeçalho
header_bgcolor #c9b2ed
# Tamanho da fonte
font_size 14px
# Tamanho da fonte do cabeçalho
header_font_size 14px
# Tamanho da fonte do título
title_font_size 14px
# Cor de fundo do texto
background_color #f3f3f3
# Cor do texto
text_color #000
# Cor de fundo do texto
text_bgcolor lavender
# Cor do título
title_color #966ccc
# URL da imagem do logotipo
logo_image https://i.postimg.cc/Gtq5tfNL/logo-transparent.png
# Texto do logotipo
logo_text "ConectaNet Reports"
# Cor do texto do logotipo
logo_text_color #966ccc
# Diretório temporário
temporary_dir /tmp
# Diretório de saída dos relatórios
output_dir /var/www/html/squid-reports
# Resolver IPs
resolve_ip no
# Exibir IPs do usuário
user_ip no
# Campo de ordenação para os principais usuários
topuser_sort_field BYTES reverse
# Campo de ordenação para os usuários
user_sort_field BYTES reverse
# Arquivo de exclusão de usuários
exclude_users /etc/sarg/exclude_users
# Arquivo de exclusão de hosts
exclude_hosts /etc/sarg/exclude_hosts
# Formato da data
date_format u
# Último log
lastlog 0
# Remover arquivos temporários
remove_temp_files yes
# Indexar os relatórios
index yes
# Organização dos índices em árvore de arquivos
index_tree file
# Sobrescrever relatórios existentes
overwrite_report yes
# Registros sem identificação de usuário
records_without_userid ip
# Utilizar vírgula como separador
use_comma yes
# Utilitário de e-mail
mail_utility mailx
# Número de principais sites
topsites_num 100
# Ordem de classificação dos principais sites
topsites_sort_order CONNECT D
# Ordem de classificação do índice
index_sort_order D
# Códigos de exclusão
exclude_codes /etc/sarg/exclude_codes
# Tempo máximo de duração
max_elapsed 28800000
# Tipo de relatório
report_type topusers topsites sites_users users_sites date_time denied auth_failures site_user_time_date downloads
# Arquivo de tabela de usuários
usertab /etc/sarg/usertab
# URLs longas
long_url no
# Data e hora por bytes
date_time_by bytes
# Conjunto de caracteres
charset Latin1
# Exibir mensagem de sucesso
show_successful_message no
# Exibir estatísticas de leitura
show_read_statistics no
# Campos do relatório de principais usuários
topuser_fields NUM DATE_TIME USERID CONNECT BYTES %BYTES IN-CACHE-OUT USED_TIME MILISEC %TIME TOTAL AVERAGE
# Campos do relatório de usuários
user_report_fields CONNECT BYTES %BYTES IN-CACHE-OUT USED_TIME MILISEC %TIME TOTAL AVERAGE
# Número de principais usuários
topuser_num 0
# Exibir logotipo do SARG
show_sarg_logo no
# Arquivo CSS externo
external_css_file http://192.168.0.254/squid-reports/style.css
# Sufixo para download
download_suffix "zip,arj,bzip,gz,ace,doc,iso,adt,bin,cab,com,dot,drv$,lha,lzh,mdb,mso,ppt,rtf,src,shs,sys,exe,dll,mp3,avi,mpg,mpeg"
```

<br><br>

## DHCP

### Instalar o isc-dhcp-server
```bash
sudo apt install isc-dhcp-server
```

<br>

### Configurar o arquivo /etc/dhcp/dhcpd.conf
conteúdo do arquivo [adicionar ao fim do arquivo]:
```bash
# Configuração do serviço DHCP.
authoritative;
subnet 192.168.0.0 netmask 255.255.255.0 {
        range 192.168.0.10 192.168.0.200;
        option domain-name-servers 192.168.0.254, 8.8.8.8, 1.1.1.1;
        option domain-name "srv-dhcp.conectanet.lan";
        option subnet-mask 255.255.255.0;
        option routers 192.168.0.254;
        option broadcast-address 192.168.0.255;
        default-lease-time 600;
        max-lease-time 7200;
        }
```

#### Configurar interface para execução do DHCP
```bash
sudo vi /etc/default/isc-dhcp-server
```
conteúdo do arquivo:
```bash
INTERFACES="enp2s0"
```

#### Reiniciar o serviço isc-dhcp-server
```bash
sudo service isc-dhcp-server restart
```

<br><br>

## Active Directory (samba-ad-dc)

### Instalar as dependências

<br>

```bash
sudo apt install build-essential libacl1-dev libattr1-dev libblkid-dev libgnutls-dev libreadline-dev python-dev libpam0g-dev python-dnspython gdb pkg-config libpopt-dev libldap2-dev dnsutils libbsd-dev docbook-xsl libcups2-dev nfs-kernel-server samba samba-common smbclient cifs-utils samba-vfs-modules samba-testsuite samba-dbg acl attr samba-dsdb-modules cups cups-common cups-core-drivers nmap winbind smbclient libnss-winbind libpam-winbind python3 krb5-user krb5-config -y
```

#### Campos de configuração do KERBEROS
```bash
# Realm
CONECTANET.LAN
# Servers
srv-cnet.conectanet.lan
# ADM Server
srv-cnet.conectanet.lan
```

<br>

### Desabilitar serviços e ativar o `samba-ad-dc`
```bash
sudo systemctl disable --now nmbd smbd winbind

sudo systemctl enable samba-ad-dc
sudo systemctl unmask samba-ad-dc
```

<br>

### Renomeando o arquivo `smb.conf`
```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

<br>

### Provisionando o domínio
```bash
sudo samba-tool domain provision --use-rfc2307 --use-xattr=yes --interactive

# Campo REALM
    conectanet.lan
# Campo DOMAIN
    conectanet
# Campo SERVER ROLE
    dc
# Campo DNS BACKEND
    SAMBA_INTERNAL
# Campo DNS FORWARDER
    8.8.8.8
# Campo ADMINISTRATOR PASSWORD
    AdmCnet@2024
```

<br>

### Substituir o arquivo krb5.conf
```bash
cp /var/lib/samba/private/krb5.conf /etc/
```

### Iniciar o `samba-ad-dc` e reiniciar o servidor
```bash
sudo systemctl start samba-ad-dc
reboot
```
