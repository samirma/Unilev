// This script checks the balance of specified ERC20 tokens and the native ETH balance for a given wallet.
// It reads the private key, RPC URL, and token contract addresses from a .env file located in the parent directory.

// Import necessary libraries
const { ethers } = require("ethers");
require("dotenv").config({ path: "../.env" });

// Minimal ABI for ERC20 tokens to get balance, symbol, and decimals
const erc20Abi = [
  "function balanceOf(address owner) view returns (uint256)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
];

/**
 * The main function to connect to the blockchain, load the wallet, and fetch balances.
 */
async function main() {
  // Check if required environment variables are set
  if (!process.env.RPC_URL || !process.env.PRIVATE_KEY) {
    console.error(
      "Error: Please make sure RPC_URL and PRIVATE_KEY are set in your ../.env file."
    );
    process.exit(1);
  }

  // Set up the provider and wallet using the updated ethers v6 syntax
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const address = wallet.address;

  console.log(`Wallet Address: ${address}`);
  console.log("====================================================");
  console.log("Fetching Balances...");
  console.log("----------------------------------------------------");

  // Fetch and display the native ETH balance
  try {
    const ethBalance = await provider.getBalance(address);
    console.log('ETH (Native):');
    // Updated for ethers v6: ethers.utils.formatEther -> ethers.formatEther
    console.log(`  - Balance: ${ethers.formatEther(ethBalance)}`);
    console.log("----------------------------------------------------");
  } catch (error) {
    console.error("Could not fetch ETH balance:", error.message);
    console.log("----------------------------------------------------");
  }

  // List of token symbols to check from the .env file
  const tokensToCheck = ["WBTC", "WETH", "USDC", "DAI"];

  // Loop through each token, create a contract instance, and fetch its balance
  for (const tokenSymbol of tokensToCheck) {
    const tokenAddress = process.env[tokenSymbol];

    if (!tokenAddress) {
      console.warn(`Warning: Contract address for ${tokenSymbol} not found in ../.env file. Skipping.`);
      continue;
    }

    try {
      // Create a contract instance for the token
      const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);

      // Fetch the balance, symbol, and decimals in parallel
      const [balance, symbol, decimals] = await Promise.all([
        tokenContract.balanceOf(address),
        tokenContract.symbol(),
        tokenContract.decimals(),
      ]);

      // Updated for ethers v6: ethers.utils.formatUnits -> ethers.formatUnits
      const formattedBalance = ethers.formatUnits(balance, decimals);

      // Log the result
      console.log(`${symbol} (${tokenSymbol}):`);
      console.log(`  - Address: ${tokenAddress}`);
      console.log(`  - Balance: ${formattedBalance}`);
      console.log("----------------------------------------------------");
    } catch (error) {
      console.error(`Error fetching balance for ${tokenSymbol} (${tokenAddress}):`, error.message);
      console.log("----------------------------------------------------");
    }
  }
}

// Execute the main function and catch any top-level errors
main().catch((error) => {
  console.error("An unexpected error occurred:", error);
  process.exit(1);
});

