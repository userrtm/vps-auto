#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="v2.8.4"
CHAT_ID="1867937414"

# GUVENLIK: Yeni BotFather tokenini buraya yaz.
BOT_TOKEN="YENI_BOT_TOKENINI_BURAYA_YAZ"

# GitHub RAW adresini buraya yaz.
TEMPLATE_URL="https://raw.githubusercontent.com/GITHUB_KULLANICI/GITHUB_REPO/main/dile28.json"
OUTPUT_NAME="dile28.json"

if [[ $EUID -ne 0 ]]; then
  echo "Bu script root olarak calistirilmali."
  exit 1
fi

if [[ "$BOT_TOKEN" == "YENI_BOT_TOKENINI_BURAYA_YAZ" ]]; then
  echo "HATA: Script icindeki BOT_TOKEN alanina yeni Telegram bot tokenini yaz."
  exit 1
fi

if [[ "$TEMPLATE_URL" == *"GITHUB_KULLANICI"* ]]; then
  echo "HATA: TEMPLATE_URL icindeki GitHub kullanici/repo adresini duzelt."
  exit 1
fi

echo "[1/6] 3x-ui $VERSION kuruluyor..."
export VERSION
printf "\n\n\n\n" | bash <(curl -fsSL "https://raw.githubusercontent.com/MHSanaei/3x-ui/$VERSION/install.sh") "$VERSION"

echo "[2/6] Panel ayarlari yapiliyor..."
# Senin kullandigin menu girdileri aynen uygulanir.
printf "7\ny\nobi\nobi\ny\ny\n" | x-ui

echo "[3/6] Panel bilgileri okunuyor..."
DB="/etc/x-ui/x-ui.db"
if [[ ! -f "$DB" ]]; then
  echo "HATA: $DB bulunamadi."
  exit 1
fi

command -v sqlite3 >/dev/null 2>&1 || {
  apt-get update -y >/dev/null
  apt-get install -y sqlite3 >/dev/null
}

get_setting() {
  sqlite3 "$DB" "SELECT value FROM settings WHERE key='$1' LIMIT 1;" 2>/dev/null || true
}

PORT="$(get_setting webPort)"
BASE_PATH="$(get_setting webBasePath)"

if [[ -z "$PORT" ]]; then
  echo "HATA: x-ui webPort okunamadi."
  exit 1
fi

# Base path bos degilse / ile baslat ve / ile bitir.
if [[ -n "$BASE_PATH" ]]; then
  BASE_PATH="/${BASE_PATH#/}"
  BASE_PATH="${BASE_PATH%/}/"
else
  BASE_PATH="/"
fi

PUBLIC_IP="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -4fsS --max-time 10 https://ifconfig.me/ip || true)"
fi
if [[ -z "$PUBLIC_IP" ]]; then
  echo "HATA: VPS public IP bulunamadi."
  exit 1
fi

PANEL_URL="http://${PUBLIC_IP}:${PORT}${BASE_PATH}"
echo "Panel: $PANEL_URL"

echo "[4/6] JSON sablonu GitHub'dan indiriliyor..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL "$TEMPLATE_URL" -o "$TMP"

echo "[5/6] Sadece panels[0].ip degistiriliyor..."
python3 - "$TMP" "$PANEL_URL" <<'PY'
import json, sys
path, panel_url = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data.get("panels"), list) or not data["panels"]:
    raise SystemExit("HATA: JSON icinde panels[0] bulunamadi.")

data["panels"][0]["ip"] = panel_url

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY

cp "$TMP" "/root/$OUTPUT_NAME"

echo "[6/6] Dosya Telegram'a gonderiliyor..."
CAPTION="✅ Yeni VPS hazir
Panel: $PANEL_URL
Kullanici: obi
Dosya: $OUTPUT_NAME"

RESP="$(curl -fsS \
  -F "chat_id=$CHAT_ID" \
  -F "caption=$CAPTION" \
  -F "document=@/root/$OUTPUT_NAME" \
  "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument")"

if [[ "$RESP" != *'"ok":true'* ]]; then
  echo "HATA: Telegram dosya gonderimi basarisiz."
  echo "$RESP"
  exit 1
fi

echo
echo "===================================="
echo " TAMAMLANDI"
echo " Panel: $PANEL_URL"
echo " Kullanici: obi"
echo " Sifre: obi"
echo " Telegram: $OUTPUT_NAME gonderildi"
echo "===================================="
