# ConectaNet

<br>

<br>

Este guia apresenta uma visão detalhada das configurações e serviços essenciais implantados nos servidores ConectaNet. Compreende a configuração de um firewall robusto, a implementação de um servidor proxy para aprimorar o desempenho e a segurança das conexões à Internet, a gestão dinâmica de endereços IP por meio do DHCP e a integração do samba-ad-dc como Controlador de Domínio, permitindo autenticação centralizada e gerenciamento de usuários e computadores.

Destinado a administradores de sistemas e equipes de suporte de TI, este documento oferece instruções passo a passo para configurar e otimizar cada componente, desde a configuração básica da máquina e da rede até a instalação e personalização dos serviços mencionados.

Por meio de procedimentos claros e exemplos práticos, espera-se que este guia seja uma ferramenta valiosa na administração eficiente do ambiente de servidores da ConectaNet, garantindo a segurança, estabilidade e desempenho dos sistemas.

# Servidor 'cnet-fw' (Firewall e Proxy)

## Configuração Básica

### Informações da Máquina
- **Nome da máquina:**      cnet-fw
- **Sistema operacional:**  ubuntu server 16.04 LTS
- **Nome de usuário:**      conectanet
- **Senha:**                ConectaNet@2024

### Configuração de Rede
- **Endereço da rede:**     192.168.0.0/24
- **Endereço do servidor:** 192.168.0.254
- **Interfaces de rede:**   eno1, enp3s0
- **Domínio:**              conectanet.lan

### Serviços e Aplicativos Instalados
- **Firewall:**             Utilizamos o iptables para garantir a segurança e controlar o tráfego de rede.
- **Proxy:**                Utilizamos o squid como proxy, melhorando o desempenho e a segurança das conexões à internet.

<br>

### Atualização dos pacotes do sistema
Para garantir que o sistema esteja atualizado, execute o seguinte comando:
```bash
sudo apt update && sudo apt upgrade -y
```

<br>

### Configuração do arquivo de hosts
Abra e edite o arquivo com o seguinte conteúdo:
```bash
sudo vi /etc/hosts
```

#### Conteúdo do arquivo:
```bash
127.0.0.1       localhost
127.0.1.1       cnet-fw
192.168.0.254   cnet-fw.conectanet.lan cnet-fw
```

<br>

### Configuração das interfaces de rede
Abra e edite o arquivo de interfaces com o seguinte conteúdo:
```bash
sudo vi /etc/network/interfaces
```

#### Conteúdo do arquivo:
```bash
# Interface de rede externa
auto eno1
iface eno1 inet dhcp

# Interface de rede interna
auto enp3s0
iface enp2s0 inet static
	address 192.168.0.254
	netmask 255.255.255.0
	network 192.168.0.0
	broadcast 192.168.0.255
```

#### Reinicie a interface de rede
```bash
sudo systemctl restart networking
# Caso não resolva reinicie a máquina
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
nameserver 192.168.0.253
# Endereços de fallback
nameserver 8.8.8.8
nameserver 1.1.1.1
# Domínio de pesquisa para resolução de nomes
search conectanet.lan
```

#### Adicione o atributo de imutabilidade:

```bash
sudo chattr +i /etc/resolv.conf
```

<br><br>

### Arquivo de script das regras do firewall (Iptables)

#### conteúdo do arquivo firewall:
```bash
#!/bin/bash


# Variaveis locais
ext="eno1"                # Interface de rede externa
int="enp3s0"              # Interface de rede interna
lnet="192.168.0.0/24"     # endereço da rede local
server="192.168.0.254"    # endereço do servidor


#==  Funcoes para definicao de regras ======================================================#


local(){
    # Funcao para configuracao das regras de firewall para comunicacao local

    # Libera todo o trafego da lo
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT

    # Permite trafego nas portas (80, 443, 53, 123)
        iptables -A INPUT -i $ext -p tcp -m multiport --sports 80,443 -j ACCEPT
        iptables -A INPUT -p udp -m multiport --sports 53,123 -j ACCEPT
        iptables -A OUTPUT -o $ext -p tcp -m multiport --dports 80,443 -j ACCEPT
        iptables -A OUTPUT -p udp -m multiport --dports 53,123 -j ACCEPT

   # Regras DNS e HTTP adicionais
        iptables -A INPUT -d $server -p tcp --sport 80 -j ACCEPT
        iptables -A INPUT -d $server -p tcp --sport 53 -j ACCEPT
        iptables -A INPUT -d $server -p udp --sport 53 -j ACCEPT

    # Libera o trafego DHCP
        iptables -A INPUT -p udp --dport 68 -j ACCEPT
        iptables -A OUTPUT -p udp --sport 68 -j ACCEPT
        iptables -A INPUT -p udp --dport 67 -j ACCEPT
        iptables -A OUTPUT -p udp --sport 67 -j ACCEPT

    # Permitir tráfego ICMP de entrada e saída
        iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s -j ACCEPT
        iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
        # Descartar tráfego ICMP de entrada e saída além das regras permitidas acima
        iptables -A INPUT -p icmp -j DROP
        iptables -A OUTPUT -p icmp -j DROP

    # Libera o trafego TCP do Squid (3128)
        iptables -A INPUT -i $int -p tcp --dport 3128 -j ACCEPT
        iptables -A OUTPUT -o $int -p tcp --sport 3128 -j ACCEPT

    # libera total acesso a porta SSH (22)
        iptables -A INPUT -i $int -p tcp --dport 22 -j ACCEPT
        iptables -A OUTPUT -o $int -p tcp --sport 22 -j ACCEPT


    # Regras para permitir conexões relacionadas e estabelecidas
        iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
}


forward(){
    # Funcao para encaminhamento de trafego entre WAN e LAN

    # Libera o trafego entre a INTERNET e a REDE LOCAL
        iptables -A FORWARD -i $ext -p tcp -m multiport --sports 80,443 -d $lnet -j ACCEPT
        iptables -A FORWARD -i $ext -p udp -m multiport --sports 53,123 -d $lnet -j ACCEPT
        iptables -A FORWARD -i $int -p tcp -m multiport --dports 80,443 -s $lnet -j ACCEPT
        iptables -A FORWARD -i $int -p udp -m multiport --dports 53,123 -s $lnet -j ACCEPT

    # Permitir tráfego ICMP de encaminhamento necessários para o funcionamento normal
        iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 10/s -j ACCEPT
        iptables -A FORWARD -p icmp --icmp-type echo-reply -m limit --limit 10/s -j ACCEPT
        # Descartar tráfego ICMP de encaminhamento além das regras permitidas acima
        iptables -A FORWARD -p icmp -j DROP
}


internet(){
    # Funcao para habilitar o compartilhamento da internet entre as redes

    # Habilita o encaminhamento de IP
    sysctl -w net.ipv4.ip_forward=1

    # Configura NAT para o trafego da LAN para a Internet
    iptables -t nat -A POSTROUTING -s $lnet -o $ext -j MASQUERADE

    # Direcionar navegacao na porta HTTP (80) para a porta do proxy/squid (3128)
    iptables -t nat -A PREROUTING -i $int -p tcp --dport 80 -j REDIRECT --to-port 3128
}


#==  Funcoes de controle  ==================================================================#

default() {
    iptables -N LOGGING
    iptables -A LOGGING -m limit --limit 5/min -j LOG --log-prefix "iptables-denied: " --log-level 7
    iptables -A LOGGING -j DROP

    iptables -A INPUT -j LOGGING
    iptables -A OUTPUT -j LOGGING
    iptables -A FORWARD -j LOGGING

    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
}

iniciar(){
    # Funcao para iniciar o firewall
    local
    forward
    internet
    default
}


parar(){
    # Funcao para parar o firewall
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
    iptables -X
}


#==  Script para controle do firewall  =====================================================#


case $1 in
    start|Start|START)iniciar;;
    stop|Stop|STOP)parar;;
    restart|Restart|RESTART)parar;iniciar;;
    listar|list)iptables -nvL;;
    vi|conf)sudo vi /usr/local/sbin/firewall;;
    *)echo "usage:
    firewall [start|stop|restart|list|vi]";;
esac
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

### Instalar o squid3 e apache2
```bash
sudo apt install squid3 apache2
```

<br>

### Configuração do squid
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

#### Pasta de cache do squid
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


#### Criar pasta files e arquivo negados.acl
```bash
sudo mkdir /etc/squid/files
sudo touch /etc/squid/files/negados.acl
```

#### Reiniciar o squid
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

### Configuração do sarg
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

# Servidor 'cnet-ad' (samba-ad-dc e DHCP)

## Configuração Básica

### Informações da Máquina
- **Nome da máquina:**      cnet-ad
- **Sistema operacional:**  ubuntu server 16.04 LTS
- **Nome de usuário:**      conectanet
- **Senha:**                ConectaNet@2024

### Configuração de Rede
- **Endereço da rede:**     192.168.0.0/24
- **Endereço do servidor:** 192.168.0.253
- **Interfaces de rede:**   eno1
- **Domínio:**              conectanet.lan

### Serviços e Aplicativos Instalados
 - **DHCP:** Utilizamos o isc-dhcp-server para gerenciar a atribuição dinâmica de endereços IP na nossa rede local.
- **AD:** Configuramos o samba-ad-dc para autenticação centralizada e gerenciamento de usuários e computadores.

<br>

### Atualização dos pacotes do sistema
Para garantir que o sistema esteja atualizado, execute o seguinte comando:
```bash
sudo apt update && sudo apt upgrade -y
```

<br>

### Configuração do arquivo de hosts
Abra e edite o arquivo com o seguinte conteúdo:
```bash
sudo vi /etc/hosts
```

#### Conteúdo do arquivo:
```bash
127.0.0.1       localhost
127.0.1.1       cnet-ad
192.168.0.253   cnet-ad.conectanet.lan cnet-ad
```

<br>

### Configuração das interfaces de rede
Abra e edite o arquivo de interfaces com o seguinte conteúdo:
```bash
sudo vi /etc/network/interfaces
```

#### Conteúdo do arquivo:
```bash

# Interface de rede interna
auto eno1
iface eno1 inet static
	address 192.168.0.253
	netmask 255.255.255.0
	network 192.168.0.0
	broadcast 192.168.0.255
	gateway 192.168.0.254
	dns-nameservers 192.168.0.253 8.8.8.8 1.1.1.1
	dns-search conectanet.lan
	dns-domain conectanet.lan
```

#### Reinicie a interface de rede
```bash
sudo systemctl restart networking
# Caso não resolva reinicie a máquina
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
nameserver 192.168.0.253
# Endereços de fallback
nameserver 8.8.8.8
nameserver 1.1.1.1
# Domínio de pesquisa para resolução de nomes
search conectanet.lan
```

#### Adicione o atributo de imutabilidade:

```bash
sudo chattr +i /etc/resolv.conf
```

<br><br>


## DHCP

### Instalar o isc-dhcp-server
```bash
sudo apt install isc-dhcp-server
```

<br>

### Configurar o arquivo dhcp.conf

```bash
sudo vi /etc/dhcp/dhcpd.conf
```

#### conteúdo do arquivo [adicionar ao fim do arquivo]:
```bash
# Configuração do serviço DHCP.
authoritative;
subnet 192.168.0.0 netmask 255.255.255.0 {
        range 192.168.0.10 192.168.0.200;
        option domain-name-servers 192.168.0.253, 8.8.8.8, 1.1.1.1;
        option domain-name "cnet-dhcp.conectanet.lan";
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
INTERFACES="eno1"
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
cnet-ad.conectanet.lan
# ADM Server
cnet-ad.conectanet.lan
```

<br>

### Desabilitar serviços e ativar o samba-ad-dc
```bash
sudo systemctl disable --now nmbd smbd winbind

sudo systemctl enable samba-ad-dc
sudo systemctl unmask samba-ad-dc
```

<br>

### Renomear o arquivo smb.conf
```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

<br>

### Provisionar o domínio
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
