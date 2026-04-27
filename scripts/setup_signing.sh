#!/usr/bin/env bash
set -euo pipefail

# setup_signing.sh — one-time setup стабильного code-signing сертификата.
# После запуска у тебя в login.keychain появляется идентичность
# «HelloWork Self-Signed». Все билды подписываются ей, и TCC видит
# одну и ту же подпись через все версии — accessibility/screen recording
# юзеры выдают РАЗ и оно живёт.
#
# Запускать один раз на dev-машине. Идемпотентно — если cert уже есть, выйдет.

CERT_NAME="HelloWork Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
PASS="hellowork-cert"  # пасс только для p12-обёртки во время импорта, ключ потом живёт открытым в keychain

if security find-identity -p codesigning -v "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "✓ Идентичность '$CERT_NAME' уже есть в Keychain — ничего не делаю"
    security find-identity -p codesigning -v "$KEYCHAIN" | grep "$CERT_NAME" | sed 's/^/  /'
    exit 0
fi

echo "▶ Генерю self-signed code-signing cert '$CERT_NAME'..."

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# X.509 cert + private key. extendedKeyUsage = codeSigning — важно,
# без него codesign будет ругаться «no identity found».
cat > "$TMP/openssl.cnf" <<'EOF'
[req]
distinguished_name = req_dn
prompt = no
x509_extensions = v3_ext

[req_dn]
CN = HelloWork Self-Signed
O = HelloWork
OU = Distribution

[v3_ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMP/key.pem" \
    -out "$TMP/cert.pem" \
    -days 3650 -nodes \
    -config "$TMP/openssl.cnf" 2>&1 | grep -v "^[+.]\+$" || true

# Упаковываем в .p12 для импорта в Keychain.
openssl pkcs12 -export \
    -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -name "$CERT_NAME" \
    -passout "pass:$PASS"

echo "▶ Импортирую в login.keychain..."
security import "$TMP/cert.p12" \
    -P "$PASS" \
    -A \
    -t cert \
    -f pkcs12 \
    -k "$KEYCHAIN" \
    >/dev/null

# Разрешаем codesign использовать ключ без всплывающего prompt'а на каждый билд.
echo "▶ Разрешаю codesign использовать ключ silently..."
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "" \
    "$KEYCHAIN" \
    >/dev/null 2>&1 || \
    echo "  (если попросит пароль — введи пароль от login keychain)"

echo
echo "✓ Готово. Идентичность в Keychain:"
security find-identity -p codesigning -v "$KEYCHAIN" | grep "$CERT_NAME" | sed 's/^/  /'
echo
echo "Дальше: scripts/build.sh подхватит её автоматически."
