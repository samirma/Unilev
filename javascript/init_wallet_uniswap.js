// This script initializes a wallet by swapping a small amount of ETH for an exact amount of DAI
// by interacting directly with the Uniswap V3 Swap Router in a single transaction.

// Import necessary libraries
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

// --- ABIs ---
// Minimal ABI for the Uniswap V3 SwapRouter contract
const swapRouterAbi = [
    "function exactOutputSingle(tuple(address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountOut, uint256 amountInMaximum, uint160 sqrtPriceLimitX96)) external payable returns (uint256 amountIn)"
];

/**
 * The main function that connects to the blockchain, initializes the wallet, and executes the swap.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const { RPC_URL, PRIVATE_KEY, WETH, DAI } = process.env;
  const SWAP_ROUTER_ADDRESS = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

  if (!RPC_URL || !PRIVATE_KEY || !WETH || !DAI) {
    console.error(
      "Error: Ensure RPC_URL, PRIVATE_KEY, WETH, and DAI are set in ../.env"
    );
    process.exit(1);
  }

  // --- Provider & Wallet Setup ---
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  console.log(`Using wallet address: ${wallet.address}`);

  // --- Contract Instance ---
  const swapRouterContract = new ethers.Contract(SWAP_ROUTER_ADDRESS, swapRouterAbi, wallet);

  // --- Swap Parameters ---
  // The exact amount of DAI we want to receive.
  const amountOutDai = "10";
  const amountOutWei = ethers.parseUnits(amountOutDai, 18); // DAI has 18 decimals

  // The maximum amount of ETH we are willing to spend to get the exact amount of DAI.
  const amountInMaxEth = "0.01";
  const amountInMaxWei = ethers.parseEther(amountInMaxEth);

  // The fee tier for the WETH/DAI pool. 3000 = 0.3%.
  const poolFee = 3000;

  console.log("\nPreparing to swap ETH for exactly 10 DAI via Uniswap V3 Router...");
  console.log(`  - Swapping at most: ${amountInMaxEth} ETH`);
  console.log(`  - To receive exactly: ${amountOutDai} DAI`);
  console.log(`  - Using Swap Router: ${SWAP_ROUTER_ADDRESS}`);
  console.log("----------------------------------------------------");

  try {
    // --- Execute The Swap in a Single Transaction ---
    console.log("Sending swap transaction...");
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from now

    const params = {
      tokenIn: WETH,
      tokenOut: DAI,
      fee: poolFee,
      recipient: wallet.address,
      deadline: deadline,
      amountOut: amountOutWei,
      amountInMaximum: amountInMaxWei,
      sqrtPriceLimitX96: 0,
    };
    
    // By providing a `value` in the transaction overrides, we send ETH directly
    // to the payable `exactOutputSingle` function. The router handles wrapping ETH to WETH.
    const swapTx = await swapRouterContract.exactOutputSingle(params, {
      value: amountInMaxWei, // Send the max ETH amount, unused ETH will be refunded
      gasLimit: 500000,
    });

    console.log(`Swap transaction sent! Hash: ${swapTx.hash}`);
    console.log("Waiting for transaction to be mined...");

    const receipt = await swapTx.wait();
    
    console.log("====================================================");
    console.log("✅ Swap Successful!");
    console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log("You should now have received exactly 10 DAI in your wallet.");
    console.log("====================================================");

  } catch (error) {
    console.error("\n❌ An error occurred during the swap process:");
    console.error(error.reason || error.message);
    process.exit(1);
  }
}

// --- Script Execution ---
main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});

