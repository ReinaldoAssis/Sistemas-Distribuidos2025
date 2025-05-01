#!/bin/bash
# Define color variables
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
#----------------------------------------------------start--------------------------------------------------#

echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

# Task 1: Create the VM instance

# Create VPC network
echo "${CYAN}${BOLD}Creating VPC network privatenet...${RESET}"
gcloud compute networks create privatenet --subnet-mode=custom

# Create subnet
echo "${CYAN}${BOLD}Creating subnet privatenet-us...${RESET}"
gcloud compute networks subnets create privatenet-us \
    --network=privatenet \
    --region=us-central1 \
    --range=10.130.0.0/20

# Create firewall rule
echo "${CYAN}${BOLD}Creating firewall rule for SSH via IAP...${RESET}"
gcloud compute firewall-rules create privatenet-allow-ssh \
    --network=privatenet \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20

# Create VM without external IP
echo "${CYAN}${BOLD}Creating VM instance vm-internal...${RESET}"
gcloud compute instances create vm-internal \
    --zone=us-central1-f \
    --machine-type=e2-medium \
    --subnet=privatenet-us \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --no-address

echo "${GREEN}${BOLD}VM instance created successfully!${RESET}"
sleep 30

# Task 2: Enable Private Google Access

# Create a Cloud Storage bucket
echo "${CYAN}${BOLD}Creating a Cloud Storage bucket...${RESET}"
BUCKET_NAME="bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)"
echo "Bucket name: $BUCKET_NAME"

gcloud storage buckets create gs://$BUCKET_NAME \
    --location=us

# Copy an image to the bucket
echo "${CYAN}${BOLD}Copying image to bucket...${RESET}"
gcloud storage cp gs://cloud-training/gcpnet/private/access.svg gs://$BUCKET_NAME

# Enable Private Google Access
echo "${CYAN}${BOLD}Enabling Private Google Access...${RESET}"
gcloud compute networks subnets update privatenet-us \
    --region=us-central1 \
    --enable-private-ip-google-access

echo "${GREEN}${BOLD}Private Google Access enabled!${RESET}"
sleep 15

# Task 3: Configure a Cloud NAT gateway

# Create a Cloud Router
echo "${CYAN}${BOLD}Creating a Cloud Router...${RESET}"
gcloud compute routers create nat-router \
    --network=privatenet \
    --region=us-central1

# Configure a Cloud NAT gateway
echo "${CYAN}${BOLD}Configuring a Cloud NAT gateway...${RESET}"
gcloud compute routers nats create nat-config \
    --router=nat-router \
    --region=us-central1 \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips

echo "${GREEN}${BOLD}Cloud NAT gateway configured!${RESET}"
sleep 60

# Task 4: Configure Cloud NAT Logging

# Enable logging for the NAT gateway
echo "${CYAN}${BOLD}Enabling logging for the NAT gateway...${RESET}"
gcloud compute routers nats update nat-config \
    --router=nat-router \
    --region=us-central1 \
    --enable-logging

echo "${GREEN}${BOLD}NAT logging enabled!${RESET}"

echo "${BG_GREEN}${BOLD}All tasks completed successfully!${RESET}"
echo "${YELLOW}${BOLD}Note:${RESET} The quiz questions can be answered as follows:"
echo "1. The command prompt will change to @vm-internal when you SSH to vm-internal: ${GREEN}True${RESET}"
echo "2. VM instances that can access the image from your bucket: ${GREEN}Cloud Shell${RESET} (initially, before enabling Private Google Access)"

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#