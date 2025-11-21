#!/usr/bin/env bash
#
# Usage: 
#   ./generate_jwt.sh <KEY_JSON> <AUDIENCE_URL> [<LIFETIME_SEC>]
#
#   KEY_JSON       : path to service-account JSON key file
#   AUDIENCE_URL   : the full URL you’ll use as the “aud” claim
#   LIFETIME_SEC   : optional, seconds until expiry (default: 3600)
#
# Example usage: 
#   JWT=$(./generate_jwt.sh service-account.json "https://my-service-url" 3600)
#   curl -H "Authorization: Bearer $JWT" https://my-service-url

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <key-json> <audience_url> [lifetime_sec]" >&2
  exit 1
fi

KEYFILE="$1"
AUD="$2"
LIFETIME="${3:-3600}"

SA_EMAIL=$(jq -r .client_email < "$KEYFILE")
PRIVATE_KEY=$(jq -r .private_key < "$KEYFILE" | sed 's/\\n/\n/g')
KEY_ID=$(jq -r .private_key_id < "$KEYFILE")

if [ -z "$SA_EMAIL" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$KEY_ID" ]; then
  echo "Error: missing client_email, private_key or private_key_id in key file" >&2
  exit 1
fi

# Header
HEADER_JSON=$(jq -n --arg kid "$KEY_ID" '{alg:"RS256", typ:"JWT", kid:$kid}')
HEADER_BASE64=$(printf '%s' "$HEADER_JSON" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Claims
NOW=$(date +%s)
EXP=$(( NOW + LIFETIME ))

CLAIMS_JSON=$(jq -n \
  --arg iss "$SA_EMAIL" \
  --arg sub "$SA_EMAIL" \
  --arg aud "$AUD" \
  --arg iat "$NOW" \
  --arg exp "$EXP" \
  '{iss:$iss, sub:$sub, aud:$aud, iat:( $iat | tonumber ), exp:( $exp | tonumber )}')

CLAIMS_BASE64=$(printf '%s' "$CLAIMS_JSON" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

BODY="${HEADER_BASE64}.${CLAIMS_BASE64}"

# Signature
SIGNATURE=$(printf '%s' "$BODY" | openssl dgst -sha256 -sign <(printf '%s' "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

JWT="${BODY}.${SIGNATURE}"

# Output only the JWT
printf '%s\n' "$JWT"