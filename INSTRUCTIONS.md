# Instrucciones de instalación y ejecución

## Requisitos

- **Bash** 4.0 o superior

- **OpenSSL** 1.1.1 o superior

- **Linux**, **MacOS** o **WSL** (Windows Subsystem for Linux)

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/carlossanchezh/criptosistema-remitente-destinatario.git
```
>Si falta el directorio `destinatario` al clonar el repositorio, créalo manualmente:
>```bash
>mkdir -p destinatario
>```

### 2. Dar permisos de ejecución 

```bash
chmod +x criptosistema.sh
```
>Necesario para poder invocar el script directamente con `./criptosistema.sh` Si prefieres no darlo, puedes ejecutarlo con `bash criptosistema.sh`.

## Ejecución

### 1. Preparar el mensaje a enviar

Edita `remitente/secreto.txt` con el contenido que quieras enviar.

### 2. Ejecutar el script

El script ha de ejecutarse desde la raíz del proyecto ya que usa rutas relativas.

```bash
./criptosistema.sh
```
