#!/bin/bash
# Load Testing Script for Frontend Auto-Scaling Demo (ALB Request Count)
# Generates sustained high request volume to trigger request-based auto-scaling

set -e

# Configuration
FRONTEND_ALB_URL="${1:-}"
CONCURRENT_USERS=150  # Higher than CPU-based test
TOTAL_REQUESTS=100000 # More requests to sustain load
TEST_DURATION=420     # 7 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}BMI App Auto-Scaling Load Test${NC}"
echo -e "${GREEN}(ALB Request Count Based Scaling)${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if ALB URL is provided
if [ -z "$FRONTEND_ALB_URL" ]; then
    echo -e "${RED}Error: Frontend ALB URL not provided${NC}"
    echo "Usage: $0 <frontend-alb-url>"
    echo "Example: $0 http://bmi-frontend-alb-1234567890.us-east-1.elb.amazonaws.com"
    exit 1
fi

# Remove trailing slash if present
FRONTEND_ALB_URL=${FRONTEND_ALB_URL%/}

echo -e "Target: ${YELLOW}${FRONTEND_ALB_URL}${NC}"
echo -e "Concurrent Users: ${YELLOW}${CONCURRENT_USERS}${NC}"
echo -e "Total Requests: ${YELLOW}${TOTAL_REQUESTS}${NC}"
echo -e "Duration: ${YELLOW}${TEST_DURATION} seconds${NC}"
echo -e "${CYAN}Target: 1000 requests/minute per instance${NC}"
echo ""

# Check if Apache Bench is installed
if ! command -v ab &> /dev/null; then
    echo -e "${YELLOW}Apache Bench (ab) not found. Installing...${NC}"
    
    # Detect OS and install
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo yum install -y httpd-tools || sudo apt-get install -y apache2-utils
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "ab should be pre-installed on macOS"
    else
        echo -e "${RED}Please install Apache Bench (ab) manually${NC}"
        exit 1
    fi
fi

# Test connectivity
echo -e "${YELLOW}Testing connectivity...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "${FRONTEND_ALB_URL}" | grep -q "200"; then
    echo -e "${RED}Error: Cannot connect to ${FRONTEND_ALB_URL}${NC}"
    echo "Please verify the ALB URL is correct and accessible"
    exit 1
fi
echo -e "${GREEN}✓ Connection successful${NC}"
echo ""

# Function to generate POST data
generate_post_data() {
    cat << EOF
{
  "weightKg": $((RANDOM % 50 + 50)),
  "heightCm": $((RANDOM % 50 + 150)),
  "age": $((RANDOM % 40 + 20)),
  "sex": "male",
  "activity": "moderate",
  "measurementDate": "$(date +%Y-%m-%d)"
}
EOF
}

# Create temp file for POST data
POST_DATA=$(mktemp)
generate_post_data > "$POST_DATA"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Starting ALB Request Count Load Test${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo -e "${YELLOW}Phase 1: Warmup (20 seconds)${NC}"
echo "Light traffic to establish baseline..."
ab -n 500 -c 5 "${FRONTEND_ALB_URL}/" > /dev/null 2>&1 &
sleep 20

echo -e "${YELLOW}Phase 2: Gradual Ramp-up (40 seconds)${NC}"
echo "Increasing request rate gradually..."
ab -n 3000 -c 30 "${FRONTEND_ALB_URL}/" > /dev/null 2>&1 &
sleep 40

echo -e "${YELLOW}Phase 3: Sustained High Request Volume${NC}"
echo "Target: 2000+ requests/min to trigger scaling"
echo ""

# Launch multiple concurrent load generators for high request rate
echo "Starting Load Generator 1: Homepage requests"
ab -n $((TOTAL_REQUESTS / 3)) -c ${CONCURRENT_USERS} -t ${TEST_DURATION} "${FRONTEND_ALB_URL}/" > /dev/null 2>&1 &
LOAD1_PID=$!

sleep 2

echo "Starting Load Generator 2: API GET requests"
ab -n $((TOTAL_REQUESTS / 3)) -c ${CONCURRENT_USERS} -t ${TEST_DURATION} "${FRONTEND_ALB_URL}/api/measurements" > /dev/null 2>&1 &
LOAD2_PID=$!

sleep 2

echo "Starting Load Generator 3: API POST requests"
ab -n $((TOTAL_REQUESTS / 6)) -c $((CONCURRENT_USERS / 2)) -t ${TEST_DURATION} \
   -p "$POST_DATA" -T "application/json" \
   "${FRONTEND_ALB_URL}/api/measurements" > /dev/null 2>&1 &
LOAD3_PID=$!

sleep 2

echo "Starting Load Generator 4: Trends API requests"
ab -n $((TOTAL_REQUESTS / 6)) -c $((CONCURRENT_USERS / 2)) -t ${TEST_DURATION} \
   "${FRONTEND_ALB_URL}/api/measurements/trends" > /dev/null 2>&1 &
LOAD4_PID=$!

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Load Test Running (7 minutes)${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Monitor ALB Request Count metrics:${NC}"
echo "  1. CloudWatch > Metrics > ApplicationELB"
echo "  2. Select your ALB > RequestCountPerTarget"
echo "  3. Watch it climb above 1000 requests/minute per instance"
echo "  4. ASG will scale out when threshold is crossed"
echo ""
echo -e "${YELLOW}Expected Behavior:${NC}"
echo "  - Start: 2 instances (~1000 req/min each = 2000 total)"
echo "  - Load: 4000+ req/min total"
echo "  - Scaling: Adds instances to distribute load"
echo "  - Result: ~1000 req/min per instance maintained"
echo ""
echo -e "${YELLOW}In AWS Console:${NC}"
echo "  - CloudWatch > Metrics > ALB > RequestCountPerTarget"
echo "  - EC2 > Auto Scaling Groups > [Your ASG] > Activity"
echo "  - Target Group > Targets (watch new instances registering)"
echo ""
echo -e "${YELLOW}Current time: $(date '+%H:%M:%S')${NC}"
echo -e "${YELLOW}Expected completion: $(date -d '+7 minutes' '+%H:%M:%S' 2>/dev/null || date -v+7M '+%H:%M:%S')${NC}"
echo ""
echo -e "${RED}Press Ctrl+C to stop the test early${NC}"
echo ""

# Progress indicator
for i in {1..42}; do
    sleep 10
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Test running... (${i}0 seconds elapsed)${NC}"
done

# Wait for all tests to complete
wait $LOAD1_PID 2>/dev/null
wait $LOAD2_PID 2>/dev/null
wait $LOAD3_PID 2>/dev/null
wait $LOAD4_PID 2>/dev/null

# Cleanup
rm -f "$POST_DATA"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Load Test Complete${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}What happened:${NC}"
echo "  1. Generated 4000+ requests/minute"
echo "  2. ALB distributed load across available targets"
echo "  3. When RequestCountPerTarget > 1000, scaling triggered"
echo "  4. New instances launched and registered"
echo "  5. Load redistributed to maintain target metric"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Check Auto Scaling Group activity history"
echo "  2. Review CloudWatch RequestCountPerTarget metric"
echo "  3. Wait 5-10 minutes for scale-in (after cooldown)"
echo "  4. Verify instances terminating back to desired capacity"
echo ""
echo -e "${GREEN}Done!${NC}"
