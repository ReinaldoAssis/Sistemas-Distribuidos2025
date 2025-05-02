

#!/bin/bash
# Define color variables

export REGION=us-central1
export ZONE_1=us-central1-a
export ZONE_2=us-central1-b
export PROJECT_ID=$(gcloud config get-value project)

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

echo "${BG_MAGENTA}${BOLD}Starting VPC Firewall Rules Lab${RESET}"

# Check if environment variables are set
if [ -z "$REGION" ] || [ -z "$ZONE1" ] || [ -z "$ZONE2" ]; then
    echo "${BG_RED}${BOLD}Please set the REGION, ZONE1, and ZONE2 variables before running the script${RESET}"
    echo "Example:"
    echo "export REGION=us-central1"
    echo "export ZONE1=us-central1-a"
    echo "export ZONE2=us-central1-b"
    exit 1
fi

# Task 1: Create VPC networks and instances
echo "${BLUE}${BOLD}Task 1: Creating VPC networks and instances...${RESET}"

# Create mynetwork (auto mode)
gcloud compute networks create mynetwork --subnet-mode=auto
echo "${GREEN}Created mynetwork with auto subnet mode${RESET}"

# Create privatenet (custom mode)
gcloud compute networks create privatenet --subnet-mode=custom
echo "${GREEN}Created privatenet with custom subnet mode${RESET}"

# Create custom subnet in privatenet
gcloud compute networks subnets create privatesubnet \
  --network=privatenet \
  --region=$REGION \
  --range=10.0.0.0/24 \
  --enable-private-ip-google-access
echo "${GREEN}Created privatesubnet in privatenet${RESET}"

# Create VMs
echo "${BLUE}Creating VM instances...${RESET}"

# Create default-vm-1
gcloud compute instances create default-vm-1 \
  --machine-type e2-micro \
  --zone=$ZONE1 \
  --network=default
echo "${GREEN}Created default-vm-1${RESET}"

# Create mynet-vm-1
gcloud compute instances create mynet-vm-1 \
  --machine-type e2-micro \
  --zone=$ZONE1 \
  --network=mynetwork
echo "${GREEN}Created mynet-vm-1${RESET}"

# Create mynet-vm-2
gcloud compute instances create mynet-vm-2 \
  --machine-type e2-micro \
  --zone=$ZONE2 \
  --network=mynetwork
echo "${GREEN}Created mynet-vm-2${RESET}"

# Create privatenet-bastion
gcloud compute instances create privatenet-bastion \
  --machine-type e2-micro \
  --zone=$ZONE1 \
  --subnet=privatesubnet \
  --can-ip-forward
echo "${GREEN}Created privatenet-bastion${RESET}"

# Create privatenet-vm-1
gcloud compute instances create privatenet-vm-1 \
  --machine-type e2-micro \
  --zone=$ZONE1 \
  --subnet=privatesubnet
echo "${GREEN}Created privatenet-vm-1${RESET}"

sleep 30

# Task 2: Investigate the default network
echo -e "\n${BLUE}${BOLD}Task 2: Investigating default network...${RESET}"
echo "${YELLOW}The default network has pre-configured firewall rules:${RESET}"
echo "- default-allow-internal: Allows internal traffic"
echo "- default-allow-ssh: Allows SSH connections from anywhere"
echo "- default-allow-rdp: Allows RDP connections from anywhere"
echo "- default-allow-icmp: Allows ICMP traffic from anywhere"

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: SSH into default-vm-1 from the console${RESET}"
echo "1. Go to the Google Cloud Console"
echo "2. Navigate to Compute Engine > VM instances"
echo "3. Click SSH button for default-vm-1 instance"
echo "4. Try ping www.google.com to verify connectivity"
echo "5. Press Ctrl+C to stop ping"
echo "6. Type 'exit' to close the SSH connection"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

echo "${BLUE}Deleting default-vm-1 instance...${RESET}"
gcloud compute instances delete default-vm-1 --zone=$ZONE1 --quiet

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Delete the default network${RESET}"
echo "1. Go to the Google Cloud Console"
echo "2. Navigate to VPC network > VPC networks"
echo "3. Click on the 'default' network"
echo "4. Click Delete VPC Network"
echo "5. Confirm deletion"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

# Task 3: Investigate user-created networks
echo -e "\n${BLUE}${BOLD}Task 3: Investigating user-created networks...${RESET}"
echo "${YELLOW}Attempting to SSH into mynet-vm-2 (should fail without custom firewall rules)${RESET}"
echo "gcloud compute ssh qwiklabs@mynet-vm-2 --zone=$ZONE2"
echo "${YELLOW}This command should fail with error code 255 as no SSH access is allowed by default${RESET}"

# Task 4: Create custom ingress firewall rules
echo -e "\n${BLUE}${BOLD}Task 4: Creating custom ingress firewall rules...${RESET}"

# Get external IP address
echo "${YELLOW}Retrieving external IP address from Cloud Shell${RESET}"
ip=$(curl -s https://api.ipify.org)
echo "My External IP address is: $ip"

# Create SSH ingress firewall rule
echo "${BLUE}Creating SSH ingress firewall rule...${RESET}"
gcloud compute firewall-rules create \
  mynetwork-ingress-allow-ssh-from-cs \
  --network mynetwork --action ALLOW --direction INGRESS \
  --rules tcp:22 --source-ranges $ip --target-tags=lab-ssh
echo "${GREEN}Created firewall rule with source IP $ip${RESET}"

# Add lab-ssh tag to VMs
echo "${BLUE}Adding lab-ssh tag to VMs...${RESET}"
gcloud compute instances add-tags mynet-vm-2 \
  --zone=$ZONE2 \
  --tags lab-ssh
gcloud compute instances add-tags mynet-vm-1 \
  --zone=$ZONE1 \
  --tags lab-ssh
echo "${GREEN}Added lab-ssh tag to mynet-vm-1 and mynet-vm-2${RESET}"

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: SSH into mynet-vm-2 and mynet-vm-1${RESET}"
echo "Run the following commands in Cloud Shell:"
echo "gcloud compute ssh qwiklabs@mynet-vm-2 --zone=$ZONE2"
echo "Type 'exit' when done"
echo "gcloud compute ssh qwiklabs@mynet-vm-1 --zone=$ZONE1"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

echo "${BLUE}Creating ICMP internal firewall rule...${RESET}"
gcloud compute firewall-rules create \
  mynetwork-ingress-allow-icmp-internal --network \
  mynetwork --action ALLOW --direction INGRESS --rules icmp \
  --source-ranges 10.128.0.0/9
echo "${GREEN}Created ICMP internal firewall rule${RESET}"

# Get project ID for internal ping test
PROJECT_ID=$(gcloud config get-value project)
echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Test internal ping${RESET}"
echo "While SSH'd into mynet-vm-1, run:"
echo "ping mynet-vm-2.$ZONE2.c.$PROJECT_ID.internal"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

# Task 5: Set the firewall rule priority
echo -e "\n${BLUE}${BOLD}Task 5: Setting firewall rule priority...${RESET}"

echo "${BLUE}Creating deny ICMP rule with priority 500...${RESET}"
gcloud compute firewall-rules create \
  mynetwork-ingress-deny-icmp-all --network \
  mynetwork --action DENY --direction INGRESS --rules icmp \
  --priority 500
echo "${GREEN}Created deny ICMP rule with priority 500${RESET}"

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Test ping with deny rule${RESET}"
echo "While SSH'd into mynet-vm-1, run:"
echo "ping mynet-vm-2.$ZONE2.c.$PROJECT_ID.internal"
echo "It should fail due to the deny rule with priority 500"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

echo "${BLUE}Updating deny ICMP rule priority to 2000...${RESET}"
gcloud compute firewall-rules update \
  mynetwork-ingress-deny-icmp-all \
  --priority 2000
echo "${GREEN}Updated deny ICMP rule to priority 2000${RESET}"

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Test ping with updated priority${RESET}"
echo "While SSH'd into mynet-vm-1, run:"
echo "ping mynet-vm-2.$ZONE2.c.$PROJECT_ID.internal"
echo "It should work now because allow rule (priority 1000) is evaluated before deny rule (priority 2000)"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

# Task 6: Configure egress firewall rules
echo -e "\n${BLUE}${BOLD}Task 6: Configuring egress firewall rules...${RESET}"

echo "${BLUE}Listing current firewall rules...${RESET}"
gcloud compute firewall-rules list \
  --filter="network:mynetwork"

echo "${BLUE}Creating egress deny rule for ICMP...${RESET}"
gcloud compute firewall-rules create \
  mynetwork-egress-deny-icmp-all --network \
  mynetwork --action DENY --direction EGRESS --rules icmp \
  --priority 10000
echo "${GREEN}Created egress deny rule with priority 10000${RESET}"

echo "${BLUE}Listing updated firewall rules...${RESET}"
gcloud compute firewall-rules list \
  --filter="network:mynetwork"

echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Test ping with egress deny rule${RESET}"
echo "While SSH'd into mynet-vm-1, run:"
echo "ping mynet-vm-2.$ZONE2.c.$PROJECT_ID.internal"
echo "It should fail even though egress rule has higher priority (10000)"
echo "This is because both ingress AND egress rules must allow traffic"
echo "${YELLOW}Press Enter when finished with the manual step...${RESET}"
read

echo "${BG_GREEN}${BOLD}Lab complete! You have successfully:${RESET}"
echo "✅ Created VPC networks (automatic and custom)"
echo "✅ Created and tested ingress firewall rules"
echo "✅ Configured firewall rule priorities"
echo "✅ Created and tested egress firewall rules"
echo "✅ Verified how both ingress and egress rules affect network traffic"

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#