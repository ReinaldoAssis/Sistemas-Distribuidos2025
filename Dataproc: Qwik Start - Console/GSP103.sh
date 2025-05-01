#!/bin/bash

# Definir variáveis de cores para melhorar a visualização no terminal
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

# Tarefa 1: Criar um cluster Dataproc
echo "Criando cluster Dataproc..."
gcloud dataproc clusters create example-cluster \
    --region us-east4 \
    --zone us-east4-a \
    --master-machine-type e2-standard-2 \
    --master-boot-disk-size 30 \
    --num-workers 2 \
    --worker-machine-type e2-standard-2 \
    --worker-boot-disk-size 30 \
    --project $PROJECT_ID \
    --no-address

# Tarefa 2: Submeter um job Spark
echo "Submetendo job Spark..."
gcloud dataproc jobs submit spark \
    --cluster example-cluster \
    --region us-east4 \
    --class org.apache.spark.examples.SparkPi \
    --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
    -- 1000

# Tarefa 4: Atualizar o cluster para modificar o número de workers
echo "Atualizando o número de workers..."
gcloud dataproc clusters update example-cluster \
    --region us-east4 \
    --num-workers 4

echo "${BG_GREEN}${BOLD}Execução do Script Concluída com Sucesso!${RESET}"