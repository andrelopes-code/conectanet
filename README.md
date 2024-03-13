# ConectaNet

<br>

<br>

## Configuração Básica

### Informações da Máquina
- Nome da máquina: **srv-conectanet**
- sistema operacional: **ubuntu server 16.04 LTS**
- Nome de usuário: **conectanet**
- Senha: **ConectaNet@2023.2**
- domínio: **conecta.net**

<br>

### Atualização dos Pacotes do Sistema
Para garantir que o sistema esteja atualizado, execute os seguintes comandos:
```bash
sudo apt update
sudo apt upgrade -y
```

<br>

### Configuração do Arquivo `/etc/hosts`
Edite o arquivo `/etc/hosts` com o seguinte conteúdo:
```bash
sudo vi /etc/hosts
```
conteúdo do arquivo:
```bash
127.0.0.1       localhost
127.0.1.1       srv-conectanet
192.168.15.254  srv-conectanet.conecta.net      srv-conectanet

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

<br>

### Configuração das Interfaces de Rede
Edite o arquivo `/etc/network/interfaces` com o seguinte conteúdo:
```bash
sudo vi /etc/network/interfaces
```
conteúdo do arquivo:
```bash
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# Interface de rede primária
auto eno1
iface eno1 inet dhcp

# Interface de rede secundária
auto enp2s0
iface enp2s0 inet static

address 192.168.15.254
netmask 255.255.255.0
network 192.168.15.0
broadcast 192.168.15.255
dns-nameserver 192.168.15.254 192.168.3.254 8.8.8.8 1.1.1.1
dns-domain conecta.net
dns-search conecta.net
```

<br>

<br>

## Firewall Iptables

### Arquivo de Script das Regras do Firewall (Iptables)

conteúdo do arquivo `firewall`:
```bash
#!/bin/bash


# Variaveis locais
ifaceEx="enp0s3"            # Interface de rede externa
ifaceIn="enp0s8"            # Interface de rede interna
localnet="192.168.15.0/24"  # endereço da rede local                  

#==  Funcoes para definicao de regras =============================================================#

local()
{
    # Funcao para configuracao das regras de firewall para comunicacao local

    # Libera a comunicacao (I/O) do servidor com a rede local e com a internet
    # Permite trafego TCP e UDP de entrada e saida nas portas
    # 80, 443, 53, 123 (HTTP, HTTPS, DNS, NTP)
    iptables -t filter -A INPUT -i $ifaceEx -p tcp -m multiport --sports 80,443 -j ACCEPT
    iptables -t filter -A INPUT -i $ifaceEx -p udp -m multiport --sports 53,123 -j ACCEPT
    iptables -t filter -A OUTPUT -o $ifaceEx -p tcp -m multiport --dports 80,443 -j ACCEPT
    iptables -t filter -A OUTPUT -o $ifaceEx -p udp -m multiport --dports 53,123 -j ACCEPT

    # Libera todo o trafego da lo na rede
    iptables -t filter -A INPUT -i lo -j ACCEPT
    iptables -t filter -A OUTPUT -o lo -j ACCEPT

    # Libera o ping (ICMP) no localhost
    iptables -t filter -A INPUT -i $ifaceEx -p icmp --icmp-type 0 -j ACCEPT
    iptables -t filter -A INPUT -i $ifaceIn -p icmp --icmp-type 0 -j ACCEPT
    iptables -t filter -A OUTPUT -o $ifaceEx -p icmp --icmp-type 8 -j ACCEPT
    iptables -t filter -A OUTPUT -o $ifaceIn -p icmp --icmp-type 8 -j ACCEPT

    # Libera o trafego TCP do Squid (3128)
    iptables -t filter -A INPUT -i $ifaceIn -p tcp --dport 3128 -j ACCEPT
    iptables -t filter -A OUTPUT -o $ifaceIn -p tcp --sport 3128 -j ACCEPT

    # Libera trafego nas portas do Samba (139 e 445)
    iptables -t filter -A INPUT -p tcp -m multiport --dports 139,445 -j ACCEPT
    iptables -t filter -A OUTPUT -p tcp -m multiport --sports 139,445 -j ACCEPT
    
    # SSH
    iptables -t filter -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -t filter -A OUTPUT -p tcp --sport 22 -j ACCEPT
}

forward()
{
    # Funcao para encaminhamento de trafego entre WAN e LAN

    # Libera o trafego entre a INTERNET e a REDE LOCAL
    iptables -t filter -A FORWARD -i $ifaceEx -p tcp -m multiport --sports 80,443 -d $localnet -j ACCEPT
    iptables -t filter -A FORWARD -i $ifaceEx -p udp -m multiport --sports 53,123 -d $localnet -j ACCEPT
    iptables -t filter -A FORWARD -i $ifaceIn -p tcp -m multiport --dports 80,443 -s $localnet -j ACCEPT
    iptables -t filter -A FORWARD -i $ifaceIn -p udp -m multiport --dports 53,123 -s $localnet -j ACCEPT

    # Libera o ping entre a INTERNET e a REDE LOCAL
    iptables -t filter -A FORWARD -i $ifaceIn -p icmp --icmp-type 8 -s $localnet -j ACCEPT
    iptables -t filter -A FORWARD -o $ifaceIn -p icmp --icmp-type 0 -d $localnet -j ACCEPT
    iptables -t filter -A FORWARD -i $ifaceEx -p icmp --icmp-type 0 -d $localnet -j ACCEPT
    iptables -t filter -A FORWARD -o $ifaceEx -p icmp --icmp-type 8 -s $localnet -j ACCEPT
}

internet()
{ 
    # Funcao para habilitar o compartilhamento da internet entre as redes

    # Habilita o encaminhamento de IP
    sysctl -w net.ipv4.ip_forward=1

    # Configura NAT para o trafego da LAN para a Internet
    iptables -t nat -A POSTROUTING -s $localnet -o $ifaceEx -j MASQUERADE
    
    # Direcionar navegacao na porta HTTP (80) para a porta do proxy/squid (3128)
    iptables -t nat -A PREROUTING -i $ifaceIn -p tcp --dport 80 -j REDIRECT --to-port 3128
}

default()
{
    # Funcao para definir as regras padrao

    # Bloqueia tudo que não foi explicitamente liberado
    iptables -t filter -P INPUT DROP
    iptables -t filter -P OUTPUT DROP
    iptables -t filter -P FORWARD DROP
}

#==  Funcoes de controle  =========================================================================#

iniciar()
{
    # Funcao para iniciar o firewall

    local
    forward
    default
    internet
}

parar()
{
    # Funcao para parar o firewall

    iptables -t filter -P INPUT ACCEPT
    iptables -t filter -P OUTPUT ACCEPT
    iptables -t filter -P FORWARD ACCEPT
    iptables -t filter -F
}

#==  Script para controle do firewall  ============================================================#

case $1 in
start|Start|START)iniciar;;
stop|Stop|STOP)parar;;
restart|Restart|RESTART)parar;iniciar;;
listar|list)iptables -t filter -nvL;;
vi|conf)sudo vi /usr/local/sbin/firewall;;
*)echo "usage: 
firewall [start|stop|restart|list|vi]";;
esac

<br>

```
#### Tornar o script um executavel
```bash
sudo chmod +x firewall
```

<br>

#### Mover o script para uma pasta do $PATH
```bash
sudo mv firewall /usr/local/sbin
```

<br>

### Inicialização Automática do Script Firewall

<br>

#### Criar o arquivo de serviço do firewall
```bash
sudo vi /lib/systemd/system/firewall.service
```
conteúdo do arquivo:
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

<br>

#### Recarregar daemons do sistema
```bash
sudo systemctl daemon-reload
```

<br>

#### Ativar o serviço do firewall
```bash
sudo systemctl enable firewall.service
```

<br>

<br>

## Proxy Squid

### Instalar o Squid3 e Apache2
```bash
sudo apt install squid3 apache2
```

<br>

### Arquivo de Configuração do Squid
```bash
sudo vi /etc/squid/squid.conf
```
conteúdo do arquivo:
```bash
#==  ACL's padrao  ============================================================#
acl SSL_ports port 443 563 873                                                        
acl Safe_ports port 80 21 443 70 210 280 488 591 777 8080 3128                    
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

#==============================================================================#

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
acl sarg dst 192.168.15.254
http_access allow sarg

#==  ACL's  ===================================================================#
acl localnet src 192.168.15.0/24
acl negados url_regex -i "/etc/squid/files/negados.acl"
 
#==  DEFAULT HTTP-ACCESS  ====================================================#
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost

#==  HTTP-ACCESS  ============================================================#
http_access allow localnet !negados

#==  DENY ALL  ===============================================================#
http_access deny all    
visible_hostname proxy_server
http_port 192.168.15.254:3128

#============================================================================#
coredump_dir /var/spool/squid
refresh_pattern ^ftp:       1440    20% 10080
refresh_pattern ^gopher:    1440    0%  1440
refresh_pattern -i (/cgi-bin/|\?) 0 0%  0
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern .       0   20% 4320
```

<br>

### Pasta de Cache do Squid
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
sudo service squid restart
```

<br>

### Página de Acesso Negado
```bash
sudo vi /usr/share/squid/errors/pt-br/ERR_ACCESS_DENIED
```
conteúdo do arquivo:
```html
<!DOCTYPE  html>
<html  lang="pt-br">
<head>
<meta  charset="UTF-8"  />
<meta  name="viewport"  content="width=device-width, initial-scale=1.0"  />
<title>Ooops!</title>
<link  rel="shortcut icon"  href="faviconWhite.ico"  type="image/x-icon"  />
<style>
@import  url("https://fonts.googleapis.com/css2?family=Poppins:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap");

*  {
margin:  0;
padding:  0;
box-sizing:  border-box;
}

html,
body  {
font-family:  "Poppins"  Arial,  Helvetica,  sans-serif;
font-size:  16px;
}
  
body  {
background-color:  rgb(240,  240,  240);
display:  flex;
height:  100vh;
justify-content:  center;
align-items:  center;
}
  
#container  {
height:  60vh;
width:  80vw;
background-color:  rgb(253,  253,  253);
border-radius:  40px;
box-shadow:  6px  6px  22px  -4px  rgba(72,  72,  72,  0.1);
padding:  108px  110px  60px  128px;
} 

#main-text  {
display:  flex;
justify-content:  space-between;
flex-direction:  column;
gap:  60px;
}

#footer  {
display:  flex;
flex-direction:  row;
justify-content:  space-between;
align-items:  center;
}
  
#main  {
display:  flex;
flex-direction:  column;
justify-content:  space-between;
height:  100%;
}

h1  {
font-size:  70px;
font-weight:  bold;
}

p  {
font-size:  20px;
font-weight:  500;
line-height:  28px;
}

a  {
font-weight:  600;
text-decoration:  none;
pointer-events:  stroke;
 
&:active {
color: rgb(201,  154,  237);
}
}
  
img  {
filter:  grayscale();
height:  40px;
}
</style>
</head>
<body>
	<div  id="container">
		<div  id="main">
			<div  id="main-text">
                <h1>Ooops!</h1>
				<p>
				Este site foi bloqueado pela ConectaNet por violar nossas políticas
				de uso.<br  />Para mais informações,
				<a  href="">entre em contato conosco</a>.
				</p>
			</div>
			<div  id="footer">
				<small>Atenciosamente, Equipe de TI da ConectaNet</small>
				<img  src="logo-transparent.png"  alt="Logo ConectaNet"  />
			</div>
		</div>
	</div>
</body>
</html>
```

<br>

### Criar pasta `files` e arquivo `negados.acl`
```bash
sudo mkdir /etc/squid/files
sudo touch /etc/squid/files/negados.acl
```

<br>

### Reiniciar o Squid
```bash
sudo service squid restart
```

<br>

<br>

## Sarg
### Instalar o Sarg
```bash
sudo apt install sarg
```

<br>

### Arquivo de configuração do Sarg
```bash
sudo vi /etc/sarg/sarg.conf
```
conteúdo do arquivo:
```bash
# Arquivo de configuração do SARG para análise de logs do Squid

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
external_css_file http://192.168.15.254/squid-reports/style.css

# Sufixo para download
download_suffix "zip,arj,bzip,gz,ace,doc,iso,adt,bin,cab,com,dot,drv$,lha,lzh,mdb,mso,ppt,rtf,src,shs,sys,exe,dll,mp3,avi,mpg,mpeg"

```

<br>

<br>

## DHCP

### Instalar o isc-dhcp-server
```bash
sudo apt install isc-dhcp-server
```

<br>

### Configurar o arquivo /etc/dhcp/dhcpd.conf
conteúdo do arquivo:
```bash
# Configuração do serviço DHCP.
authoritative;
subnet 192.168.15.0 netmask 255.255.255.0 {
        range 192.168.15.10 192.168.15.200;
        option domain-name-servers 192.168.15.254, 192.168.3.254, 8.8.8.8, 1.1.1.1;
        option domain-name "srv-dhcp.conecta.net";
        option subnet-mask 255.255.255.0;
        option routers 192.168.15.254;
        option broadcast-address 192.168.15.255;
        default-lease-time 600;
        max-lease-time 7200;
        }
```

<br>

### Configurar interface para execução do DHCP
```bash
sudo vi /etc/default/isc-dhcp-server
```
conteúdo do arquivo:
```bash
arquivo isc-dhcp-server aqui
```

<br>

### Reiniciar o serviço isc-dhcp-server
```bash
sudo service isc-dhcp-server restart
```

<br>

<br>

## AD (samba-ad-dc)
