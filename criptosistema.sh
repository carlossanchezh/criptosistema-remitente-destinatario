#!/bin/bash
set -e

# Use esta forma de navegar entre los directorios 'remitente' y 'destinatario'
cd remitente
printf "Secreto a enviar: %s\n" "$(cat secreto.txt)"

# 1. ACUERDO DE CLAVE PARA CIFRADO
cd ..
cd destinatario
if [ ! -f clave_privada_dest.pem ] || [ ! -f clave_publica_dest.pem ]; then #Solo generar clave publica y privada del destinatario si no existe
    
    openssl genrsa -out clave_privada_dest.pem 3072 # clave privada del destinatario
    openssl rsa -pubout -in clave_privada_dest.pem -out clave_publica_dest.pem # clave publica del destinatario
    cp clave_publica_dest.pem ../remitente/ # se envia la clave publica del destinatario al remitente

else

    if [ ! -f ../remitente/clave_publica_dest.pem ]; then #Si el remitente no tiene la clave publica se le envia 

        cp clave_publica_dest.pem ../remitente/ # se envia la clave publica del destinatario al remitente
    fi
fi

cd ..


cd remitente
#clave simetrica temporal para cifrar el mensaje (32 bits ya que se descifra con aes 256 ya que se usa rsa 3072)
openssl rand 32 > clave_secreta.bin
(echo "-----BEGIN ANY PRIVATE KEY-----" ; echo $(base64 clave_secreta.bin) ; echo "-----END ANY PRIVATE KEY-----") > clave_secreta.pem

#se cifra la clave temporal con la publica del destinatario
openssl pkeyutl -encrypt -pubin -inkey clave_publica_dest.pem -in clave_secreta.pem -out clave_secreta_cifrada.bin

# 2. ACUERDO DE CLAVE PARA MAC

#clave simetrica temporal para hmac (32 bits ya que se descifra con sha 256 ya que se usa rsa 3072)
openssl rand 32 > clave_mac.bin
(echo "-----BEGIN ANY PRIVATE KEY-----" ; echo $(base64 clave_mac.bin) ; echo "-----END ANY PRIVATE KEY-----") > clave_mac.pem

#se cifra la clave temporal con la publica del destinatario
openssl pkeyutl -encrypt -pubin -inkey clave_publica_dest.pem -in clave_mac.pem -out clave_mac_cifrada.bin

# 3. CIFRADO Y GENERACION PARA EL MAC

# Cifrado del mensaje con AES-256 usando la clave temporal
openssl enc -aes-256-cbc -pbkdf2 -salt -kfile clave_secreta.pem -in secreto.txt -out secreto_cifrado.bin

# Se genera el hmac del mensaje cifrado
openssl dgst -sha256 -hmac clave_mac.pem secreto_cifrado.bin > mac.bin

#ENVIO

cp secreto_cifrado.bin mac.bin clave_secreta_cifrada.bin clave_mac_cifrada.bin ../destinatario/

rm -f clave_secreta.bin clave_secreta.pem clave_mac.bin clave_mac.pem mac.bin clave_secreta_cifrada.bin clave_mac_cifrada.bin secreto_cifrado.bin

cd ..

#DESTINATARIO

cd destinatario

#4. RECEPCION SEGURA

#Se descifra la clave temporal simetrica del mensaje
openssl pkeyutl -decrypt -inkey clave_privada_dest.pem -in clave_secreta_cifrada.bin -out clave_secreta.pem
base64 -d <(sed '1d;$d' clave_secreta.pem) > clave_secreta.bin

rm -f clave_secreta_cifrada.bin 

#Se descifra la clave temporal simetrica del mac
openssl pkeyutl -decrypt -inkey clave_privada_dest.pem -in clave_mac_cifrada.bin -out clave_mac.pem
base64 -d <(sed '1d;$d' clave_mac.pem) > clave_mac.bin

rm -f clave_mac_cifrada.bin 

# Se calcula el mac y se compara con el recibido
MAC_CALCULADO=$(openssl dgst -sha256 -hmac clave_mac.pem secreto_cifrado.bin | awk '{print $2}')
MAC_GUARDADO=$(cat mac.bin | awk '{print $2}')

#Si no son iguales el mensaje fue modificado irrumpiendo con su integridad
if [ "$MAC_CALCULADO" != "$MAC_GUARDADO" ]; then
    echo "ERROR: MAC incorrecto: mensaje alterado."
    exit 1
fi

rm -f mac.bin 

#Se descifra el mensaje 
openssl enc -d -aes-256-cbc -pbkdf2 -salt -kfile clave_secreta.pem -in secreto_cifrado.bin -out secreto.txt

printf "Secreto recibido y autenticado: %s\n" "$(cat secreto.txt)"

rm -f clave_secreta.bin clave_secreta.pem clave_mac.bin clave_mac.pem secreto_cifrado.bin

cd ..

