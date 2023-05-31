-include .env

.PHONY: all test clean deploy-anvil

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install smartcontractkit/chainlink-brownie-contracts && forge install rari-capital/solmate && forge install foundry-rs/forge-std && forge install OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update:; forge update

build:; forge build --via-ir

sizer:; forge build --sizes --via-ir

compile:; forge compile --via-ir

test :; forge test -vv --gas-report --via-ir

test fork :; forge test --fork-url ${ETH_RPC_URL} -vv --gas-report --via-ir 

slither :; slither ./src 

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

anvil :; anvil -m 'test test test test test test test test test test test junk' --fork-url ${ETH_RPC_URL}

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :; @forge script src/scripts/Deployments.s.sol:Deployments --via-ir --fork-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 