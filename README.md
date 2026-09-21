# Criptosistema remitente destinatario

## Descripción

Implementación en Bash de un criptosistema híbrido que permite enviar un mensaje secreto entre un remitente y un destinatario garantizando confidencialidad, integridad y autenticación, usando OpenSSL.

El script `criptosistema.sh` simula el envío seguro de un mensaje entre dos entidades. Para ello combina criptografía **asimétrica** (RSA-3072) para intercambiar claves y criptografía **simétrica** (AES-256-CBC) para cifrar el mensaje, añadiendo además un **HMAC-SHA256** que garantiza que el mensaje no ha sido alterado en tránsito.

El resultado es un esquema *Encrypt-then-MAC* con claves simétricas efímeras generadas en cada ejecución, lo que aporta seguridad incluso si una clave simétrica se viera comprometida en el futuro.

## Arquitectura

### Modelo de seguridad 

El proyecto aplica cinco principios:

- **Confidencialidad** — AES-256-CBC con clave aleatoria por sesión

- **Autenticación de clave** — RSA-3072 (clave pública del destinatario)

- **Integridad** — HMAC-SHA256 sobre el texto cifrado

- **Autenticación del mensaje** — Solo el destinatario posee la clave del MAC

- **Claves efímeras** — Claves AES y HMAC nuevas en cada ejecución

### Funcionamiento

#### Acuerdo de clave para cifrado

1. Si el destinatario no tiene par de claves RSA, se generan: `clave_privada_dest.pem` y `clave_publica_dest.pem`
   
```bash
openssl genrsa -out clave_privada_dest.pem 3072
openssl rsa -pubout -in clave_privada_dest.pem -out clave_publica_dest.pem
```
2. La clave pública `clave_publica_dest.pem` se copia al directorio del remitente
   
```bash
cp clave_publica_dest.pem ../remitente/
```
3. El remitente genera **32 bytes aleatorios** (`clave_secreta.bin`) que serán la clave simétrica temporal para cifrar el mensaje y obtener `clave_secreta.pem`

```bash
openssl rand 32 > clave_secreta.bin
(echo "-----BEGIN ANY PRIVATE KEY-----" ; echo $(base64 clave_secreta.bin) ; echo "-----END ANY PRIVATE KEY-----") > clave_secreta.pem
```

4. Esta clave simétrica temporal `clave_secreta.pem` se cifra con la clave pública del destinatario y se obtiene `clave_secreta_cifrada.bin`

```bash
openssl pkeyutl -encrypt -pubin -inkey clave_publica_dest.pem -in clave_secreta.pem -out clave_secreta_cifrada.bin
```

#### Acuerdo de clave para el MAC

1. El remitente genera **32 bytes aleatorios** (`clave_mac.bin`) que serán la clave simétrica temporal para cifrar hmac y obtener `clave_mac.pem`

```bash
openssl rand 32 > clave_mac.bin
(echo "-----BEGIN ANY PRIVATE KEY-----" ; echo $(base64 clave_mac.bin) ; echo "-----END ANY PRIVATE KEY-----") > clave_mac.pem
```

2. Esta clave simétrica temporal `clave_mac.pem` se cifra con la clave pública del destinatario y produce `clave_mac_cifrada.bin`

```bash
openssl pkeyutl -encrypt -pubin -inkey clave_publica_dest.pem -in clave_mac.pem -out clave_mac_cifrada.bin
```

#### Cifrado y generación del MAC

1. Cifrado del mensaje `secreto.txt` con AES-256-CBC usando la clave secreta obteniendo `secreto_cifrado.bin`

```bash
openssl enc -aes-256-cbc -pbkdf2 -salt -kfile clave_secreta.pem -in secreto.txt -out secreto_cifrado.bin
```

2. Se genera el hmac del mensaje cifrado `secreto_cifrado.bin` y `clave_mac.pem` obteniendo `mac.bin`

```bash
openssl dgst -sha256 -hmac clave_mac.pem secreto_cifrado.bin > mac.bin
```

#### Envío

Se copian al directorio del destinatario los cuatro artefactos: `secreto_cifrado.bin`, `mac.bin`, `clave_secreta_cifrada.bin` y `clave_mac_cifrada.bin`. Después se borran los temporales del remitente.

```bash
cp secreto_cifrado.bin mac.bin clave_secreta_cifrada.bin clave_mac_cifrada.bin ../destinatario/
rm -f clave_secreta.bin clave_secreta.pem clave_mac.bin clave_mac.pem mac.bin clave_secreta_cifrada.bin clave_mac_cifrada.bin secreto_cifrado.bin
```

### Recepción segura

1.  Descifra la clave simétrica del mensaje `clave_secreta_cifrada.bin` con su **clave privada RSA**, se obtiene `clave_secreta.pem` y `clave_secreta.bin`.

```bash
openssl pkeyutl -decrypt -inkey clave_privada_dest.pem -in clave_secreta_cifrada.bin -out clave_secreta.pem
base64 -d <(sed '1d;$d' clave_secreta.pem) > clave_secreta.bin
```

2.  Descifra la clave simétrica del hmac `clave_mac_cifrada.bin` con su **clave privada RSA**, se obtiene `clave_mac.pem` y `clave_mac.bin`

```bash
openssl pkeyutl -decrypt -inkey clave_privada_dest.pem -in clave_mac_cifrada.bin -out clave_mac.pem
base64 -d <(sed '1d;$d' clave_mac.pem) > clave_mac.bin
```

3. **Verifica el MAC** recalculando el HMAC del mensaje cifrado y comparándolo con elrecibido. Si no coinciden, aborta con error.

```bash
MAC_CALCULADO=$(openssl dgst -sha256 -hmac clave_mac.pem secreto_cifrado.bin | awk '{print $2}')
MAC_GUARDADO=$(cat mac.bin | awk '{print $2}')
```

4. Descifra el mensaje `secreto_cifrado.bin` con AES-256-CBC y obtiene `secreto.txt`.
   
```bash
openssl enc -d -aes-256-cbc -pbkdf2 -salt -kfile clave_secreta.pem -in secreto_cifrado.bin -out secreto.txt
```
5. Limpia los archivos temporales del destinatario.

```bash
rm -f clave_secreta.bin clave_secreta.pem clave_mac.bin clave_mac.pem secreto_cifrado.bin
```
## Tecnologías

- Lenguaje / Intérprete de comandos: **Bash**
- Librería criptográfica: OpenSSL
- Algoritmo de cifrado simétrico: **AES-256-CBC**
- Cifrado de las claves simétricas: **RSA-3072**
- Código de autenticación de mensajes: **HMAC-SHA256**

## Estructura del proyecto

```plaintext

.
├── destinatario/
│   └── .gitkeep               # Conserva la carpeta vacía en Git 
│
├── remitente/
│     └── secreto.txt          # Mensaje de ejemplo a enviar   
│
├── README.md                  # Descripción del proyecto 
└── criptosistema.sh           # Script principal
```
