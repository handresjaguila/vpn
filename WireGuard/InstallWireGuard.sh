#Script made: Henoch Jelvez
#Use: Install vpn server WireGuard
#System: Linux 
#!/bin/bash
# Desinstalar cualquier versión existente de WireGuard
echo "Desinstalando WireGuard..."
apt-get remove --purge wireguard -y
rm -rf /etc/wireguard

# Actualizar el sistema operativo
echo "Actualizando sistema operativo..."
apt-get update && apt-get upgrade -y

# Descargar instalador de WireGuard
echo "Descargando instalador de WireGuard..."
wget https://git.zx2c4.com/wireguard-tools/snapshot/wireguard-tools-1.0.20210315.tar.xz

# Descomprimir archivo descargado
echo "Descomprimiendo archivo descargado..."
tar -xvf wireguard-tools-1.0.20210315.tar.xz

# Entrar al directorio descomprimido
cd wireguard-tools-1.0.20210315/src

# Instalar WireGuard
echo "Instalando WireGuard..."
make && make install

# Volver a la ruta 
cd ..
cd ..

# Generar claves privadas y públicas del servidor
echo "Generando claves privadas y públicas del servidor..."
umask 077
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key  

# Crear archivo de configuración del servidor
echo "Creando archivo de configuración del servidor..."
read -p "Ingrese el puerto para el servidor WireGuard: " PORT > conexion_vpn.txt
read -p "Ingrese la dirección IP de la red local (ejemplo: 10.0.0.1/24): " IP 

cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/server_private_key)
Address = $IP
ListenPort = $PORT

EOF

# Agregar usuario
echo "Agregando usuario..."
read -p "Ingrese el nombre de usuario: " USERNAME >> conexion_user.txt
read -s -p "Ingrese la contraseña: " PASSWORD >> conexion_password.txt
echo ""
umask 077
wg genkey | tee /etc/wireguard/$USERNAME.privatekey | wg pubkey > /etc/wireguard/$USERNAME.publickey

cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
PublicKey = $(cat /etc/wireguard/$USERNAME.publickey)
AllowedIPs = 10.0.0.2/32

EOF

# Generar archivo de configuración del cliente
echo "Generando archivo de configuración del cliente..."
cat > /etc/wireguard/client.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/$USERNAME.privatekey)
Address = 10.0.0.2/24

[Peer]
PublicKey = $(cat /etc/wireguard/server_public_key)
Endpoint = $(curl -s https://api.ipify.org):$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21
EOF

# Habilitar el reenvío de paquetes
echo "Habilitando reenvío de paquetes..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Levantar el servicio de WireGuard
echo "Levantando el servicio de WireGuard..."
wg-quick up wg0

# Obtener la dirección IP pública y el puerto
echo "Obteniendo la dirección IP pública y el puerto..."
SERVER_IP=$(curl -s https://api.ipify.org) > ip_publica.txt
echo "Dirección IP pública del servidor: $SERVER_IP" > connection_info.txt
echo "Levantando el servicio de WireGuard..."
sudo systemctl start wg-quick@wg0.service

#Obtener información de la conexión y guardarla en un archivo
echo "Guardando información de la conexión en el archivo de configuración..."
sudo wg show wg0 | sed -e '1d' -e 's/peer.*//' | awk '{print "Endpoint = " $1 ":51820\nPublicKey = " $2 "\nAllowedIPs = 0.0.0.0/0\n"}' > wg0.conf

#Hacer un archivo de configuración para enviar a la conexión agente.
wg showconf wg0 > client.conf

#Hacer un código QR
qrencode -t ansiutf8 < client.conf

#Instalar mutt para envio de correo electrónico 
sudo apt-get install mutt

#Enviar el archivo de conexión a un correo electrónico usando el cliente de correo electrónico de mutt
echo "Enviando archivo de conexión a correo electrónico..."
echo "Archivo de conexión adjunto." | mutt -a wg0.conf -s "Archivo de conexión WireGuard" -- xxx@gmail.com > salida_correo.txt
