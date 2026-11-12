
#!/bin/bash

set -euo pipefail

# =====================================================
# AWS EC2 RUNNING INSTANCE COST ESTIMATOR
# =====================================================

# Configuration
PROFILE="${AWS_PROFILE:-dev}"
REGION="${AWS_REGION:-ap-southeast-2}"
TAG_KEY="${TAG_KEY:-Environment}"
TAG_VALUE="${TAG_VALUE:-dev}"
HOURS_PER_MONTH=730

OUTPUT_DIR="reports"
OUTPUT_FILE="$OUTPUT_DIR/ec2-cost-report.csv"

# Create reports directory
mkdir -p "$OUTPUT_DIR"

# Check dependencies
for cmd in aws jq awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' is not installed."
        exit 1
    fi
done

# Display configuration
echo "================================================="
echo "          AWS EC2 COST ESTIMATOR"
echo "================================================="
echo "Profile    : $PROFILE"
echo "Region     : $REGION"
echo "Tag Filter : $TAG_KEY=$TAG_VALUE"
echo

# -----------------------------------------------------
# 1. Verify AWS Authentication
# -----------------------------------------------------

if ! aws sts get-caller-identity \
    --profile "$PROFILE" >/dev/null 2>&1; then
    echo "ERROR: AWS authentication failed."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity \
    --profile "$PROFILE" \
    --query Account \
    --output text)

echo "AWS Account: $ACCOUNT_ID"
echo

# -----------------------------------------------------
# 2. Discover All Running EC2 Instances
# -----------------------------------------------------

echo "Checking running EC2 instances..."

ALL_INSTANCES=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running" \
    --output json)

RUNNING_COUNT=$(echo "$ALL_INSTANCES" | \
    jq '[.Reservations[].Instances[]] | length')

echo "Running Instances: $RUNNING_COUNT"
echo

# -----------------------------------------------------
# 3. Automatically Apply Environment Tags
# -----------------------------------------------------

if [[ "$RUNNING_COUNT" -gt 0 ]]; then

    echo "Checking Environment tags..."

    while IFS=$'\t' read -r INSTANCE_ID ENV_TAG; do

        if [[ -z "$ENV_TAG" || "$ENV_TAG" == "None" ]]; then

            echo "Applying $TAG_KEY=$TAG_VALUE to $INSTANCE_ID"

            aws ec2 create-tags \
                --profile "$PROFILE" \
                --region "$REGION" \
                --resources "$INSTANCE_ID" \
                --tags "Key=$TAG_KEY,Value=$TAG_VALUE"

        else
            echo "$INSTANCE_ID already has $TAG_KEY=$ENV_TAG"
        fi

    done < <(
        echo "$ALL_INSTANCES" | jq -r --arg key "$TAG_KEY" '
            .Reservations[].Instances[] |
            [
                .InstanceId,
                (([.Tags[]? | select(.Key == $key) | .Value][0]) // "None")
            ] | @tsv
        '
    )

    echo
    echo "Environment tagging completed."
fi

# -----------------------------------------------------
# 4. Fetch Tagged Running Instances
# -----------------------------------------------------

echo "Fetching instances matching $TAG_KEY=$TAG_VALUE..."

INSTANCES=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters \
        "Name=instance-state-name,Values=running" \
        "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value | [0]]' \
    --output json)

COUNT=$(echo "$INSTANCES" | jq 'length')

# Prepare CSV report
echo "Instance ID,Name,Instance Type,Hourly USD,Daily USD,Monthly USD" \
    > "$OUTPUT_FILE"

# -----------------------------------------------------
# 5. Handle No Matching Instances
# -----------------------------------------------------

if [[ "$COUNT" -eq 0 ]]; then

    echo
    echo "No matching running EC2 instances found."
    echo
    echo "============== COST SUMMARY =============="
    echo "AWS Account      : $ACCOUNT_ID"
    echo "Region           : $REGION"
    echo "Matching Count   : 0"
    echo "Hourly Estimate  : \$0.0000"
    echo "Daily Estimate   : \$0.0000"
    echo "Monthly Estimate : \$0.0000"
    echo "CSV Report       : $OUTPUT_FILE"
    echo "=========================================="

    exit 0
fi

# -----------------------------------------------------
# 6. EC2 Hourly Pricing (USD)
# Sydney Region - Linux On-Demand Estimates
# Validate rates against current AWS pricing.
# -----------------------------------------------------

declare -A RATES=(
    ["t2.micro"]=0.0146
    ["t3.micro"]=0.0132
    ["t3.small"]=0.0264
    ["t3.medium"]=0.0528
    ["t3.large"]=0.1056
    ["t3.xlarge"]=0.2112
    ["t3.2xlarge"]=0.4224
    ["m5.large"]=0.1200
    ["m5.xlarge"]=0.2400
    ["c5.large"]=0.1110
    ["c5.xlarge"]=0.2220
)

# -----------------------------------------------------
# 7. Calculate Instance Costs
# -----------------------------------------------------

TOTAL_HOURLY=0
TOTAL_DAILY=0
TOTAL_MONTHLY=0
PRICED_COUNT=0
SKIPPED_COUNT=0

echo
echo "============= RUNNING EC2 INSTANCES ============="

while IFS=$'\t' read -r INSTANCE_ID INSTANCE_TYPE NAME; do

    RATE="${RATES[$INSTANCE_TYPE]:-}"

    # Skip unsupported instance types
    if [[ -z "$RATE" ]]; then
        echo "WARNING: No pricing configured for $INSTANCE_TYPE"
        ((SKIPPED_COUNT+=1))
        continue
    fi

    # Calculate costs
    DAILY=$(awk -v r="$RATE" \
        'BEGIN {printf "%.4f", r * 24}')

    MONTHLY=$(awk -v r="$RATE" -v h="$HOURS_PER_MONTH" \
        'BEGIN {printf "%.4f", r * h}')

    # Write CSV
    printf '%s,%s,%s,%s,%s,%s\n' \
        "$INSTANCE_ID" "${NAME:-N/A}" "$INSTANCE_TYPE" \
        "$RATE" "$DAILY" "$MONTHLY" >> "$OUTPUT_FILE"

    # Display instance details
    echo
    echo "Instance ID : $INSTANCE_ID"
    echo "Name        : ${NAME:-N/A}"
    echo "Type        : $INSTANCE_TYPE"
    echo "Hourly Cost : \$$RATE"
    echo "Daily Cost  : \$$DAILY"
    echo "Monthly Cost: \$$MONTHLY"
    echo "-----------------------------------------------"

    # Update totals
    TOTAL_HOURLY=$(awk -v a="$TOTAL_HOURLY" -v b="$RATE" \
        'BEGIN {printf "%.4f", a+b}')

    TOTAL_DAILY=$(awk -v a="$TOTAL_DAILY" -v b="$DAILY" \
        'BEGIN {printf "%.4f", a+b}')

    TOTAL_MONTHLY=$(awk -v a="$TOTAL_MONTHLY" -v b="$MONTHLY" \
        'BEGIN {printf "%.4f", a+b}')

    ((PRICED_COUNT+=1))

done < <(echo "$INSTANCES" | jq -r '.[] | @tsv')

# -----------------------------------------------------
# 8. Final Cost Summary
# -----------------------------------------------------

echo
echo "================================================="
echo "                  COST SUMMARY"
echo "================================================="
echo "AWS Account      : $ACCOUNT_ID"
echo "Region           : $REGION"
echo "Matching Count   : $COUNT"
echo "Priced Instances : $PRICED_COUNT"
echo "Skipped Instances: $SKIPPED_COUNT"
echo "-------------------------------------------------"
echo "Hourly Estimate  : \$$TOTAL_HOURLY"
echo "Daily Estimate   : \$$TOTAL_DAILY"
echo "Monthly Estimate : \$$TOTAL_MONTHLY"
echo "================================================="
echo "CSV Report       : $OUTPUT_FILE"
echo "================================================="
echo
echo "EC2 Cost Estimation Completed Successfully!"
