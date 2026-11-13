#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"

function check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Errore: $1 non trovato, installalo prima."; exit 1; }
}

check_cmd terraform
check_cmd ansible-playbook
check_cmd gcloud

ACTION="${1:-apply}"

if [[ "$ACTION" == "apply" ]]; then
  echo "============================================="
  echo "1. FASE TERRAFORM: Creazione Infrastruttura"
  echo "============================================="
  cd "$TF_DIR"

  terraform init -input=false
  terraform apply -auto-approve

  # La chiave SSH viene creata da Terraform nella sua cartella
  KEY_PATH="$TF_DIR/id_rsa_server"

  # Assicuriamoci che i permessi della chiave siano stretti, altrimenti SSH la rifiuta
  if [ -f "$KEY_PATH" ]; then
    chmod 600 "$KEY_PATH"
  fi

  echo "============================================="
  echo "2. FASE ANSIBLE: Configurazione Nodi"
  echo "============================================="
  cd "$ANSIBLE_DIR"

  # Verifica che Terraform abbia generato correttamente l'inventario
  if [ ! -f "inventory.ini" ]; then
    echo "Errore: File inventory.ini non trovato. Terraform non lo ha generato."
    exit 1
  fi

  # Evita il prompt "yes/no" alla prima connessione SSH
  export ANSIBLE_HOST_KEY_CHECKING=False

  # Esegue il playbook usando l'inventario generato da Terraform
  ansible-playbook -i inventory.ini playbook.yml

  echo "============================================="
  echo "DEPLOY COMPLETATO CON SUCCESSO!"
  echo "L'inventario completo con gli IP si trova in: $ANSIBLE_DIR/inventory.ini"
  echo "Usa la chiave $KEY_PATH per collegarti via SSH ai nodi."
  echo "============================================="

  cat "$ANSIBLE_DIR/inventory.ini"

elif [[ "$ACTION" == "destroy" ]]; then
  echo "============================================="
  echo "DISTRUZIONE INFRASTRUTTURA"
  echo "============================================="
  cd "$TF_DIR"
  terraform destroy -auto-approve

  # Pulizia opzionale dell'inventario residuo
  rm -f "$ANSIBLE_DIR/inventory.ini"

  echo "=== Destroy completato."
else
  echo "Uso: $0 [apply|destroy]"
  exit 2
fi
