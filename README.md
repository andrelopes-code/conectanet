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
# arquivo de configuração dos hosts.
```

<br>

### Configuração das Interfaces de Rede
Edite o arquivo `/etc/network/interfaces` com o seguinte conteúdo:
```bash
sudo vi /etc/network/interfaces
```
conteúdo do arquivo:
```bash
# arquivo de configuração das interfaces.
```

<br>

<br>

## Firewall Iptables

### Arquivo de Script das Regras do Firewall (Iptables)

conteúdo do arquivo `firewall`:
```bash
# arquivo de configuração do serviço firewall.
```

<br>

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
# arquivo de configuração do serviço proxy squid.
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
# arquivo html da pagina de acesso negado.
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
# arquivo de configuração do sarg.
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
# arquivo de configuração do serviço DHCP.
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
