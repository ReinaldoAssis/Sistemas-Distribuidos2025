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

# Prompt for region and zone
read -p "${YELLOW}${BOLD}Enter the region (e.g., europe-west1): ${RESET}" REGION
read -p "${YELLOW}${BOLD}Enter the zone (e.g., europe-west1-b): ${RESET}" ZONE

# Validate region and zone
if [ -z "$REGION" ] || [ -z "$ZONE" ]; then
    echo "${RED}${BOLD}Region and zone must be provided.${RESET}"
    exit 1
fi

# Display the configured region and zone
echo "${GREEN}${BOLD}Using Region: $REGION and Zone: $ZONE${RESET}"

# Task 1: Verify the Application Load Balancer is deployed
echo "${CYAN}${BOLD}Verifying that the Application Load Balancer is deployed...${RESET}"

# Check the health of the backend services
echo "${YELLOW}Checking the health of backend services...${RESET}"
gcloud compute backend-services get-health web-backend --global

# Wait for backends to be healthy
echo "${YELLOW}Waiting for all backends to be HEALTHY. This may take a few minutes...${RESET}"
while true; do
    HEALTHY_COUNT=$(gcloud compute backend-services get-health web-backend --global --format="json" | grep -c "HEALTHY")
    if [ "$HEALTHY_COUNT" -ge 3 ]; then
        echo "${GREEN}${BOLD}All backends are HEALTHY!${RESET}"
        break
    else
        echo "${YELLOW}Waiting for backends to be HEALTHY. Currently $HEALTHY_COUNT are healthy. Checking again in 15 seconds...${RESET}"
        sleep 15
    fi
done

# Get the load balancer IP address
echo "${CYAN}${BOLD}Retrieving the load balancer IP address...${RESET}"
LB_IP=$(gcloud compute forwarding-rules describe web-rule --global --format="value(IPAddress)")
echo "${GREEN}${BOLD}Load Balancer IP Address: $LB_IP${RESET}"
echo "${YELLOW}${BOLD}Make note of this IP address for later use.${RESET}"

# Test access to the load balancer
echo "${CYAN}${BOLD}Testing access to the load balancer...${RESET}"
echo "${YELLOW}Sending a curl request to the load balancer...${RESET}"
curl -m1 $LB_IP
echo ""
echo "${GREEN}${BOLD}You should see a response from one of the backend servers.${RESET}"

# Task 2: Create a VM to test access to the load balancer
echo "${CYAN}${BOLD}Creating a VM to test access to the load balancer...${RESET}"

# Create the access-test VM
echo "${YELLOW}Creating access-test VM in $ZONE...${RESET}"
gcloud compute instances create access-test \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud

echo "${GREEN}${BOLD}VM creation complete!${RESET}"
echo "${YELLOW}Waiting for VM to be fully ready...${RESET}"
sleep 30

# Get the external IP of the access-test VM
ACCESS_TEST_IP=$(gcloud compute instances describe access-test --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
echo "${GREEN}${BOLD}Access-test VM External IP: $ACCESS_TEST_IP${RESET}"
echo "${YELLOW}${BOLD}Make note of this IP address for the security policy.${RESET}"

# Test access to the load balancer from the VM
echo "${CYAN}${BOLD}Testing access to the load balancer from the VM...${RESET}"
echo "${YELLOW}Sending a curl request to the load balancer from the VM...${RESET}"
gcloud compute ssh access-test --zone=$ZONE --command="curl -m1 $LB_IP" --quiet

# Task 3: Create a security policy with Google Cloud Armor
echo "${CYAN}${BOLD}Creating a security policy with Google Cloud Armor...${RESET}"

# Create security policy to blocklist the access-test VM
echo "${YELLOW}Creating security policy to blocklist access-test VM...${RESET}"
gcloud compute security-policies create blocklist-access-test \
    --description="Blocklist access from the access-test VM"

# Add rule to block the access-test VM
echo "${YELLOW}Adding rule to block the access-test VM...${RESET}"
gcloud compute security-policies rules create 1000 \
    --security-policy=blocklist-access-test \
    --description="Block access-test VM" \
    --src-ip-ranges="$ACCESS_TEST_IP/32" \
    --action=deny-404

# Set the default rule to allow
echo "${YELLOW}Setting the default rule to allow...${RESET}"
gcloud compute security-policies rules update 2147483647 \
    --security-policy=blocklist-access-test \
    --action=allow

# Apply the security policy to the backend service
echo "${YELLOW}Applying the security policy to the backend service...${RESET}"
gcloud compute backend-services update web-backend \
    --global \
    --security-policy=blocklist-access-test

echo "${GREEN}${BOLD}Security policy created and applied!${RESET}"
echo "${YELLOW}It may take a few minutes for the policy to take effect.${RESET}"
sleep 60

# Verify the security policy
echo "${CYAN}${BOLD}Verifying the security policy...${RESET}"
echo "${YELLOW}Sending a curl request from the access-test VM to the load balancer...${RESET}"
echo "${YELLOW}This should now return a 404 error once the policy takes effect:${RESET}"
gcloud compute ssh access-test --zone=$ZONE --command="curl -m1 $LB_IP" --quiet

echo "${GREEN}${BOLD}You should now see a 404 error from the access-test VM.${RESET}"
echo "${GREEN}${BOLD}Try accessing the load balancer IP ($LB_IP) from your local browser.${RESET}"
echo "${GREEN}${BOLD}You should still be able to access it as we have only blocklisted the access-test VM.${RESET}"

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#