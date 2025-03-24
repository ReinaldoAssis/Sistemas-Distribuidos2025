#!/bin/bash

# Definir variáveis de cores (opcional, para melhorar a visualização no terminal)
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

echo "${BG_MAGENTA}${BOLD}Iniciando a Execução do Script${RESET}"

# Definir o ID do projeto a partir da variável de ambiente do Cloud Shell
PROJECT_ID=$DEVSHELL_PROJECT_ID

# Tarefa 1: Configurar regras de firewall para HTTP e health check
echo "Criando regras de firewall..."
gcloud compute firewall-rules create default-allow-http \
    --network default \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server

gcloud compute firewall-rules create default-allow-health-check \
    --network default \
    --allow tcp \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --target-tags http-server

# Tarefa 2: Configurar modelos de instância
echo "Criando modelos de instância..."
gcloud compute instance-templates create us-east1-template \
    --machine-type e2-micro \
    --tags http-server \
    --network default \
    --subnet projects/$PROJECT_ID/regions/us-east1/subnetworks/default \
    --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh

gcloud compute instance-templates create europe-west4-template \
    --machine-type e2-micro \
    --tags http-server \
    --network default \
    --subnet projects/$PROJECT_ID/regions/europe-west4/subnetworks/default \
    --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh

# Tarefa 2: Criar grupos de instâncias gerenciadas
echo "Criando grupos de instâncias gerenciadas..."
gcloud compute instance-groups managed create us-east1-mig \
    --region us-east1 \
    --size 1 \
    --template us-east1-template

gcloud compute instance-groups managed set-autoscaling us-east1-mig \
    --region us-east1 \
    --min-num-replicas 1 \
    --max-num-replicas 2 \
    --target-cpu-utilization 0.8 \
    --cool-down-period 45

gcloud compute instance-groups managed create europe-west4-mig \
    --region europe-west4 \
    --size 1 \
    --template europe-west4-template

gcloud compute instance-groups managed set-autoscaling europe-west4-mig \
    --region europe-west4 \
    --min-num-replicas 1 \
    --max-num-replicas 2 \
    --target-cpu-utilization 0.8 \
    --cool-down-period 45

# Tarefa 3: Configurar o Application Load Balancer
echo "Criando health check..."
gcloud compute health-checks create tcp http-health-check \
    --port 80

echo "Criando serviço de backend..."
gcloud compute backend-services create http-backend \
    --protocol HTTP \
    --health-checks http-health-check \
    --global

echo "Adicionando backends ao serviço de backend..."
gcloud compute backend-services add-backend http-backend \
    --instance-group us-east1-mig \
    --instance-group-region us-east1 \
    --balancing-mode RATE \
    --max-rate-per-instance 50 \
    --global

gcloud compute backend-services add-backend http-backend \
    --instance-group europe-west4-mig \
    --instance-group-region europe-west4 \
    --balancing-mode UTILIZATION \
    --max-utilization 0.8 \
    --global

echo "Habilitando logging no serviço de backend..."
gcloud compute backend-services update http-backend \
    --enable-logging \
    --logging-sample-rate 1.0 \
    --global

echo "Criando mapa de URL..."
gcloud compute url-maps create http-lb \
    --default-service http-backend

echo "Criando proxy HTTP alvo..."
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map http-lb

echo "Criando regras de encaminhamento..."
gcloud compute forwarding-rules create http-lb-forwarding-rule \
    --global \
    --target-http-proxy http-lb-proxy \
    --ports 80

gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv6 \
    --global \
    --target-http-proxy http-lb-proxy \
    --ports 80 \
    --ip-version IPV6

# Tarefa 4: Criar VM para teste de carga (siege-vm)
echo "Criando siege-vm..."
gcloud compute instances create siege-vm \
    --machine-type f1-micro \
    --zone us-central1-b \
    --subnet default

echo "Instalando o siege no siege-vm..."
gcloud compute ssh siege-vm --zone us-central1-b --command "sudo apt-get -y install siege"

# Tarefa 5: Configurar política de segurança com Cloud Armor
echo "Obtendo o IP do siege-vm..."
SIEGE_IP=$(gcloud compute instances describe siege-vm --zone us-central1-b --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

echo "Criando política de segurança do Cloud Armor..."
gcloud compute security-policies create denylist-siege \
    --description "Denylist siege-vm"

echo "Adicionando regra para bloquear o IP do siege-vm..."
gcloud compute security-policies rules create 1000 \
    --security-policy denylist-siege \
    --description "Deny siege-vm" \
    --src-ip-ranges $SIEGE_IP \
    --action deny-403

echo "Associando a política ao serviço de backend..."
gcloud compute backend-services update http-backend \
    --security-policy denylist-siege \
    --global

echo "${BG_GREEN}${BOLD}Execução do Script Concluída com Sucesso!${RESET}"