#!/bin/bash

# Script de download e instalação do aplicativo nx6000-voice
# executar como root: curl -fsSL URL | sudo bash

set -euo pipefail

APP_NAME="nx6000-voice"
BASE_URL="https://noxxonsat.github.io/deploy/$APP_NAME/"
TARBALL_URL="${BASE_URL}$APP_NAME.tar.gz"
CHECKSUM_URL="${BASE_URL}$APP_NAME.sha256"
INSTALL_SCRIPT="deploy/install.sh"
TMP_DIR=$(mktemp -d)

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Erro: comando obrigatório não encontrado: $1"
        exit 1
    fi
}

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

require_cmd curl
require_cmd sha256sum
require_cmd tar
require_cmd awk
require_cmd find

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root:"
    echo "curl -fsSL URL | sudo bash"
    exit 1
fi

echo "Baixando pacote..."

curl --fail --show-error --silent --location \
    --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 1 --connect-timeout 15 \
    "$TARBALL_URL" -o "$TMP_DIR/$APP_NAME.tar.gz"

echo "Baixando arquivo de verificação..."

curl --fail --show-error --silent --location \
    --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 1 --connect-timeout 15 \
    "$CHECKSUM_URL" -o "$TMP_DIR/$APP_NAME.sha256"

echo "Verificando integridade do pacote..."

cd "$TMP_DIR" || exit 1

EXPECTED_SHA256=$(awk 'NF {print $1; exit}' "$TMP_DIR/$APP_NAME.sha256")
DOWNLOADED_SHA256=$(sha256sum "$TMP_DIR/$APP_NAME.tar.gz" | awk '{print $1}')

if [ -z "$EXPECTED_SHA256" ]; then
    echo "Arquivo de checksum inválido ou vazio."
    exit 1
fi

if [ "$DOWNLOADED_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "Checksum inválido!"
    exit 1
fi

echo "Extraindo arquivos..."

tar -xzf "$TMP_DIR/$APP_NAME.tar.gz" -C "$TMP_DIR"

# Descobre automaticamente a primeira pasta extraída
APP_DIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "$APP_DIR" ]; then
    echo "Erro: pasta da aplicação não encontrada."
    exit 1
fi

echo "Executando instalador..."

cd "$APP_DIR" || exit 1

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "Erro: $INSTALL_SCRIPT não encontrado em $APP_DIR"
    exit 1
fi

bash "$INSTALL_SCRIPT"

echo "Instalação concluída."
