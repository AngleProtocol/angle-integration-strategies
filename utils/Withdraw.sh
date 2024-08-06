#!/bin/bash

# Default values
env=local
chainId=42161
strategyAddress="0xC0077E921C30c39cDD8b693E25Af572C10E82a05"
slippage=0.1
userAddress="0x25681Ab599B4E2CEea31F8B498052c53FC2D74db"
tokenChoice="usdc"
routerAddress="0x9A33e690AA78A4c346e72f7A5e16e5d7278BE835"

# Define output token addresses
USDC_ADDRESS="0xaf88d065e77c8cC2239327C5EDb3A432268e5831" # USDC on Arbitrum
USDT_ADDRESS="0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9" # USDT on Arbitrum
USDA_ADDRESS="0x0000206329b97DB379d5E1Bf586BbDB969C63274" # USDA on Arbitrum

# Parse command-line options
while getopts "e:c:i:s:r:l:u:t:" opt; do
  case $opt in
    e) env=$OPTARG ;;
    c) chainId=$OPTARG ;;
    i) inputTokenAmount=$OPTARG ;;
    s) strategyAddress=$OPTARG ;;
    r) routerAddress=$OPTARG ;;
    l) slippage=$OPTARG ;;
    u) userAddress=$OPTARG ;;
    t) tokenChoice=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Convert tokenChoice to lowercase
tokenChoice=$(echo "$tokenChoice" | tr '[:upper:]' '[:lower:]')

# Map tokenChoice to outputTokenAddress
case $tokenChoice in
    usdc) outputTokenAddress=$USDC_ADDRESS ;;
    usdt) outputTokenAddress=$USDT_ADDRESS ;;
    usda) outputTokenAddress=$USDA_ADDRESS ;;
    *)
        echo "Invalid token choice. Please use 'usdc', 'usdt', or 'usda'."
        exit 1
        ;;
esac

# Set the base URL based on the environment
case $env in
    local)
        base_url="http://localhost:5001"
        ;;
    dev)
        base_url="https://api-default-mlflm4nxmq-ew.a.run.app"
        ;;
    *)
        echo "Invalid environment. Please use 'local' or 'dev'."
        exit 1
        ;;
esac

# # Execute the cast call and store the full result
# FULL_RESULT=$(cast call $strategyAddress "maxRedeem(address)(uint256)" $userAddress --rpc-url fork)

# # Extract only the numeric part before the space
# WITHDRAW_AMOUNT=$(echo $FULL_RESULT | awk '{print $1}')

# Construct the URL
url="${base_url}/v1/integrators/payload/withdraw?chainId=$chainId&outputTokenAddress=$outputTokenAddress&inputTokenAmount=$inputTokenAmount&strategyAddress=$strategyAddress&userAddress=$userAddress&slippage=$slippage&ipAddress=none"

echo $url

# Call the URL and extract the data field
response=$(curl -s "$url")
data=$(echo "$response" | jq -r '.data')

# Check if the data field is empty or not
if [ -z "$data" ]; then
    echo "Failed to retrieve 'data' from response."
    exit 1
fi

# Print the data (for debugging purposes)
echo "Data field extracted: $data"

forge script scripts/WithdrawPayloadScript.s.sol \
    --sender "$userAddress" \
    --rpc-url fork \
    --unlocked \
    --evm-version shanghai \
    --broadcast \
    -vvvv \
    --sig "run(bytes,address,uint256,address,address)" "$data" "$outputTokenAddress" "$inputTokenAmount" "$strategyAddress" "$routerAddress"