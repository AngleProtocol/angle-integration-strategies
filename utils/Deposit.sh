#!/bin/bash

# Default values
env=local
chainId=42161
inputTokenAmount=100000000
strategyAddress="0xC0077E921C30c39cDD8b693E25Af572C10E82a05"
slippage=0.1
userAddress="0x25681Ab599B4E2CEea31F8B498052c53FC2D74db"  # USDC holder
#userAddress="0x7c490d17af51292b513C338Ebe1323B7e3BA56fA" # USDT holder
#userAddress="0xa9BB7e640FF985376e67bbb5843bF9a63a2fBa02" # USDA holder
tokenChoice="usdc"
routerAddress="0x9A33e690AA78A4c346e72f7A5e16e5d7278BE835"

# Define input token addresses
USDC_ADDRESS="0xaf88d065e77c8cC2239327C5EDb3A432268e5831" # USDC on Arbitrum
USDT_ADDRESS="0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9" # USDT on Arbitrum
USDA_ADDRESS="0x0000206329b97DB379d5E1Bf586BbDB969C63274" # USDA on Arbitrum

# Parse command-line options
while getopts "e:c:i:r:s:l:u:t:" opt; do
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

# Map tokenChoice to inputTokenAddress
case $tokenChoice in
    usdc) inputTokenAddress=$USDC_ADDRESS ;;
    usdt) inputTokenAddress=$USDT_ADDRESS ;;
    usda) inputTokenAddress=$USDA_ADDRESS ;;
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

# Construct the URL
url="${base_url}/v1/integrators/payload/deposit?chainId=$chainId&inputTokenAddress=$inputTokenAddress&inputTokenAmount=$inputTokenAmount&strategyAddress=$strategyAddress&userAddress=$userAddress&slippage=$slippage&ipAddress=none"

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

# Ask the user which RPC URL to use
echo "Which RPC URL do you want to use? (these are values from foundry.toml, check [rpc_endpoints] section and modify .env if needed)"
echo "1. arbitrum"
echo "2. fork"
read -p "Enter your choice (1 or 2): " rpc_choice

# Set the RPC URL and adjust the forge script command based on user choice
case $rpc_choice in
    1)
        rpc_url="arbitrum"
        forge_command="forge script scripts/DepositPayloadScript.s.sol \
            --sender \"$userAddress\" \
            --rpc-url $rpc_url \
            -i 1 \
            --broadcast \
            --evm-version shanghai \
            -vvvv \
            --sig \"run(bytes,address,uint256,address,address)\" \"$data\" \"$inputTokenAddress\" \"$inputTokenAmount\" \"$strategyAddress\" \"$routerAddress\""
        ;;
    2)
        rpc_url="fork"
        forge_command="forge script scripts/DepositPayloadScript.s.sol \
            --sender \"$userAddress\" \
            --rpc-url $rpc_url \
            --broadcast \
            --unlocked \
            --evm-version shanghai \
            -vvvv \
            --sig \"run(bytes,address,uint256,address,address)\" \"$data\" \"$inputTokenAddress\" \"$inputTokenAmount\" \"$strategyAddress\" \"$routerAddress\""
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Execute the forge script command
eval "$forge_command"