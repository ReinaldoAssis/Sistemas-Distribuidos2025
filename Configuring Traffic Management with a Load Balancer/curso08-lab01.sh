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

echo "${BG_MAGENTA}${BOLD}Starting Regional Internal Application Load Balancer Lab${RESET}"

# Extract PROJECT_ID and REGION information
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region 2>/dev/null)

# If REGION is not set, ask the user
if [[ -z "$REGION" ]]; then
    echo "${YELLOW}Region not set in gcloud config.${RESET}"
    # Show available regions
    echo "${CYAN}Available regions:${RESET}"
    gcloud compute regions list --format="table(name)"
    
    # Ask for region input
    echo "${YELLOW}Please enter the region to use:${RESET}"
    read REGION
    gcloud config set compute/region $REGION
    echo "${GREEN}Set region to: $REGION${RESET}"
fi

# List available zones in the region
echo "${CYAN}Available zones in $REGION:${RESET}"
gcloud compute zones list --filter="region:($REGION)" --format="table(name)"

# Ask for the first and second zones
echo "${YELLOW}Please enter the first zone (Zone 1) to use:${RESET}"
read ZONE1
echo "${YELLOW}Please enter the second zone (Zone 2) to use:${RESET}"
read ZONE2

# Set the first zone as the default zone
gcloud config set compute/zone $ZONE1

echo "${BLUE}${BOLD}Project: $PROJECT_ID${RESET}"
echo "${BLUE}${BOLD}Region: $REGION${RESET}"
echo "${BLUE}${BOLD}Zone 1: $ZONE1${RESET}"
echo "${BLUE}${BOLD}Zone 2: $ZONE2${RESET}"

# Task 1: View the Google Cloud infrastructure
echo -e "\n${BLUE}${BOLD}Task 1: Viewing pre-configured Google Cloud infrastructure...${RESET}"
echo "${YELLOW}Exploring existing infrastructure (this is informational only)...${RESET}"

echo "${CYAN}Checking VPC networks...${RESET}"
gcloud compute networks list

echo "${CYAN}Checking subnet-a and subnet-b in my-internal-app network...${RESET}"
gcloud compute networks subnets list --filter="network:my-internal-app"

echo "${CYAN}Checking firewall rules...${RESET}"
gcloud compute firewall-rules list --filter="network:my-internal-app"

echo "${CYAN}Checking instance groups...${RESET}"
gcloud compute instance-groups managed list

echo "${CYAN}Checking VM instances...${RESET}"
gcloud compute instances list

echo "${GREEN}Infrastructure exploration complete. Now creating utility-vm for testing.${RESET}"

# Create utility-vm for testing
echo "${CYAN}Creating utility-vm in subnet-a...${RESET}"
gcloud compute instances create utility-vm \
    --zone=$ZONE1 \
    --machine-type=e2-medium \
    --subnet=subnet-a \
    --private-network-ip=10.10.20.50 \
    --no-address \
    --image-family=debian-12 \
    --image-project=debian-cloud

echo "${GREEN}Created utility-vm for testing.${RESET}"

# Create a script to verify backend instances
cat > verify_backends.sh << 'EOF'
#!/bin/bash
echo "Verifying instance-group-1 in subnet-a..."
curl 10.10.20.2
echo -e "\nVerifying instance-group-2 in subnet-b..."
curl 10.10.30.2
EOF

echo "${CYAN}Uploading verification script to utility-vm...${RESET}"
gcloud compute scp verify_backends.sh utility-vm:~/ --zone=$ZONE1

echo "${CYAN}Running verification script to check backends...${RESET}"
gcloud compute ssh utility-vm --zone=$ZONE1 --command="bash ./verify_backends.sh"

# Quiz about backend identification
echo -e "\n${BG_YELLOW}${BLACK}${BOLD}QUIZ QUESTION${RESET}"
echo "${YELLOW}Which of these fields identifies the location of the backend?${RESET}"
echo "1. Client IP"
echo "2. Server Location"
echo "3. Server Hostname"
echo "${GREEN}The correct answer is: 2. Server Location${RESET}"
echo "${YELLOW}Press Enter when you have answered the question in the lab interface...${RESET}"
read

# Task 2: Configure the load balancer
echo -e "\n${BLUE}${BOLD}Task 2: Configuring the load balancer...${RESET}"
echo "${BG_RED}${BOLD}MANUAL STEP REQUIRED: Configure the load balancer in Cloud Console${RESET}"
echo "Please follow these steps in the Google Cloud Console:"
echo "1. Go to Network Services > Load balancing"
echo "2. Click Create Load Balancer"
echo "3. Under Application Load Balancer (HTTP/HTTPS), click next"
echo "4. For Public facing or internal, select internal and click next"
echo "5. For Cross-region or single region deployment, select Best for regional workloads and click next"
echo "6. Click Configure"
echo "7. Set Name to my-ilb"
echo "8. Set Region to $REGION"
echo "9. Set Network to my-internal-app"
echo "10. Reserve a proxy-only subnet:"
echo "   - Name: my-proxy-subnet"
echo "   - IP address range: 10.10.40.0/24"
echo "   - Click Add"
echo ""
echo "For the blue-service backend:"
echo "11. Click Backend configuration"
echo "12. Create a backend service named blue-service with instance-group-1 on port 80"
echo "13. Create a health check named blue-health-check (TCP on port 80)"
echo ""
echo "For the green-service backend:"
echo "14. Create another backend service named green-service with instance-group-2 on port 80"
echo "15. Create a health check named green-health-check (TCP on port 80)"
echo ""
echo "For routing rules:"
echo "16. Click Routing rules"
echo "17. Select Advanced host and path rule mode"
echo "18. Add a host and path rule with host * and the following YAML:"
echo ""
echo "defaultService: regions/$REGION/backendServices/blue-service"
echo "name: matcher1"
echo "routeRules:"
echo " - matchRules:"
echo "     - prefixMatch: /"
echo "   priority: 0"
echo "   routeAction:"
echo "     weightedBackendServices:"
echo "       - backendService: regions/$REGION/backendServices/blue-service"
echo "         weight: 70"
echo "       - backendService: regions/$REGION/backendServices/green-service"
echo "         weight: 30"
echo ""
echo "19. Configure the default routing rule to use blue-service"
echo ""
echo "For frontend configuration:"
echo "20. Set Subnetwork to subnet-b"
echo "21. Set Custom ephemeral IP address to 10.10.30.5"
echo ""
echo "22. Review and click Create"
echo ""
echo "${YELLOW}Press Enter when you have completed configuring the load balancer...${RESET}"
read

echo "${CYAN}Waiting for the load balancer to be created (this may take a few minutes)...${RESET}"
echo "${YELLOW}During this time, the load balancer is being provisioned and health checks are being performed.${RESET}"

# Wait for user confirmation that the load balancer is ready
echo "${YELLOW}Press Enter when the load balancer shows as created and healthy in the Google Cloud Console...${RESET}"
read

# Task 3: Test the load balancer
echo -e "\n${BLUE}${BOLD}Task 3: Testing the load balancer...${RESET}"

# Create a script to test the load balancer
cat > test_loadbalancer.sh << 'EOF'
#!/bin/bash
echo "Testing load balancer at 10.10.30.5..."
for i in {1..10}; do
  echo -e "\nRequest $i:"
  curl 10.10.30.5
done
EOF

echo "${CYAN}Uploading test script to utility-vm...${RESET}"
gcloud compute scp test_loadbalancer.sh utility-vm:~/ --zone=$ZONE1

echo "${CYAN}Running test script to verify load balancer traffic distribution...${RESET}"
gcloud compute ssh utility-vm --zone=$ZONE1 --command="bash ./test_loadbalancer.sh"

echo -e "\n${GREEN}${BOLD}Test results explanation:${RESET}"
echo "${YELLOW}The load balancer should route approximately:${RESET}"
echo "- 70% of traffic to instance-group-1 (blue-service)"
echo "- 30% of traffic to instance-group-2 (green-service)"
echo "${YELLOW}You should see more responses from $ZONE1 (blue-service) than from $ZONE2 (green-service).${RESET}"

echo -e "\n${BG_GREEN}${BOLD}Lab complete! You have successfully:${RESET}"
echo "✅ Explored pre-configured Google Cloud infrastructure"
echo "✅ Created a utility VM for testing"
echo "✅ Configured a regional internal Application Load Balancer"
echo "✅ Set up blue and green backend services with weighted traffic distribution"
echo "✅ Verified that traffic is properly distributed between backends"

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#