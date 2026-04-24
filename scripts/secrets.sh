#!/usr/bin/env bash
# secrets.sh - Encrypt and decrypt the ~/.secrets file using GPG symmetric encryption.
#
# USAGE:
#   ./secrets.sh encrypt   - Encrypt ~/.secrets to ../secrets.gpg (run before committing)
#   ./secrets.sh decrypt   - Decrypt ../secrets.gpg to ~/.secrets (run on a new machine)
#
# SETUP:
#   1. Run 'chmod +x secrets.sh' to make this script executable
#   2. Make sure 'secrets.gpg' is committed to your repo
#   3. Make sure '.secrets' is in your .gitignore (never commit the plain file!)
#
# REQUIREMENTS:
#   Arch Linux : sudo pacman -S gnupg
#   macOS      : brew install gnupg
#
# NOTE: You will be prompted for a passphrase on both encrypt and decrypt.
#       Store your passphrase in a password manager (e.g. Bitwarden, 1Password).

set -e

SECRETS_FILE="$HOME/.secrets"
ENCRYPTED_FILE="$(dirname "$0")/../secrets.gpg"

case "$1" in
  encrypt)
    gpg --symmetric --cipher-algo AES256 --output "$ENCRYPTED_FILE" "$SECRETS_FILE"
    echo "Encrypted to $ENCRYPTED_FILE"
    ;;
  decrypt)
    gpg --decrypt "$ENCRYPTED_FILE" >"$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    echo "Decrypted to $SECRETS_FILE"
    ;;
  *)
    echo "Usage: $0 [encrypt|decrypt]"
    ;;
esac
