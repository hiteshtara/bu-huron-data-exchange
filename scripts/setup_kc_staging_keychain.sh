#!/bin/bash

set -e

SERVICE="bu-kuali-stg"
ACCOUNT="KCOEUS"

printf "Enter KCOEUS STAGING password: "
read -s PASSWORD
printf "\n"

security add-generic-password \
  -U \
  -a "$ACCOUNT" \
  -s "$SERVICE" \
  -w "$PASSWORD"

unset PASSWORD

echo
echo "Stored KCOEUS staging password in macOS Keychain."
echo "Service: $SERVICE"
echo "Account: $ACCOUNT"
