// This script initializes a wallet by swapping a small amount of ETH for an exact amount of DAI.
// It uses the UNISWAPV3HELPER contract to perform a single-hop swap on Uniswap V3.
// Configuration is loaded from a .env file and the contract ABI is loaded from a JSON file.

// Import necessary libraries
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

/**
 * Loads the contract ABI from the JSON file.
 * @returns {object} The contract ABI.
 */
function getAbi(contractName) {
  try {
    const abiPath = path.resolve(__dirname, `../out/${contractName}.sol/${contractName}.json`);
    const abiFile = fs.readFileSync(abiPath, "utf8");
    return JSON.parse(abiFile).abi;
  } catch (error) {
    console.error(`Error loading contract ABI for ${contractName}:`, error.message);
    console.error("Please ensure the contract has been compiled and the ABI file is in the correct path.");
    process.exit(1);
  }
}

/**
 * Loads a standard WETH ABI.
 * @returns {object} The WETH contract ABI.
 */
function getWethAbi() {
    return [
        "function deposit() payable",
        "function withdraw(uint)",
        "function approve(address guy, uint wad) public returns (bool)",
        "function balanceOf(address) view returns (uint)"
    ];
}


/**
 * The main function that connects to the blockchain, initializes the wallet, and executes the swap.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const { RPC_URL, PRIVATE_KEY, UNISWAPV3HELPER_ADDRESS, WETH, DAI } = process.env;

  if (!RPC_URL || !PRIVATE_KEY || !UNISWAPV3HELPER_ADDRESS || !WETH || !DAI) {
    console.error(
      "Error: Ensure RPC_URL, PRIVATE_KEY, UNISWAPV3HELPER_ADDRESS, WETH, and DAI are set in ../.env"
    );
    process.exit(1);
  }

  // --- Load ABIs ---
  const uniswapV3HelperAbi = getAbi("UniswapV3Helper");
  const wethAbi = getWethAbi();


  // --- Provider & Wallet Setup ---
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  console.log(`Using wallet address: ${wallet.address}`);

  // --- Contract Instances ---
  const uniswapHelper = new ethers.Contract(
    UNISWAPV3HELPER_ADDRESS,
    uniswapV3HelperAbi,
    wallet
  );

  const wethContract = new ethers.Contract(WETH, wethAbi, wallet);

  // --- Get initial nonce ---
  let nonce = await wallet.getNonce();

  // --- Swap Parameters ---
  // We want to receive exactly 10 DAI from this swap.
  const amountOutDai = "10";
  const amountOutWei = ethers.parseUnits(amountOutDai, 18); // DAI has 18 decimals

  // We are willing to spend at most 0.01 WETH for this swap.
  const amountInMaxEth = "0.01";
  const amountInMaxWei = ethers.parseEther(amountInMaxEth);

  // The fee tier for the WETH/DAI pool. 3000 = 0.3%. This is a common tier for these assets.
  const poolFee = 3000;


  // --- Check WETH Balance and Wrap ETH if necessary ---
  const wethBalance = await wethContract.balanceOf(wallet.address);
  console.log(`Current WETH balance: ${ethers.formatEther(wethBalance)} WETH`);

  if (wethBalance < amountInMaxWei) {
      const ethToWrap = amountInMaxWei - wethBalance;
      console.log(`Insufficient WETH. Wrapping ${ethers.formatEther(ethToWrap)} ETH to WETH...`);
      const wrapTx = await wethContract.deposit({value: ethToWrap, nonce: nonce});
      console.log(`Wrapping transaction sent! Hash: ${wrapTx.hash}`);
      await wrapTx.wait();
      console.log("Wrapping successful!");
      const newWethBalance = await wethContract.balanceOf(wallet.address);
      console.log(`New WETH balance: ${ethers.formatEther(newWethBalance)} WETH`);
      nonce++;
  }

  // --- Approve the UniswapHelper to spend our WETH ---
  console.log("\nApproving UniswapV3Helper to spend WETH...");
  const approveTx = await wethContract.approve(UNISWAPV3HELPER_ADDRESS, amountInMaxWei, { nonce: nonce });
  console.log(`Approval transaction sent! Hash: ${approveTx.hash}`);
  await approveTx.wait();
  console.log("Approval successful!");
  nonce++;


  console.log("\nPreparing to swap WETH for exactly 10 DAI...");
  console.log(`  - Swapping at most: ${amountInMaxEth} WETH`);
  console.log(`  - To receive exactly: ${amountOutDai} DAI`);
  console.log(`  - Using helper contract: ${UNISWAPV3HELPER_ADDRESS}`);
  console.log("----------------------------------------------------");

  try {
    // --- Execute The Swap Transaction ---
    console.log("Sending transaction...");
    // Calling `swapExactOutputSingle`. The contract will use the approved WETH.
    const tx = await uniswapHelper.swapExactOutputSingle(
      WETH,               // tokenIn (WETH address)
      DAI,                // tokenOut
      poolFee,            // Uniswap V3 pool fee tier
      amountOutWei,       // The exact amount of DAI we want to receive
      amountInMaxWei,     // The maximum amount of WETH we are willing to spend
      {
        gasLimit: 500000,      // A generous gas limit for the transaction
        nonce: nonce
      }
    );

    console.log(`Transaction sent! Hash: ${tx.hash}`);
    console.log("Waiting for transaction to be mined...");

    // Wait for the transaction to be confirmed on the blockchain
    const receipt = await tx.wait();
    
    console.log("====================================================");
    console.log("✅ Swap Successful!");
    console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log("You should now have exactly 10 DAI in your wallet.");
    console.log("====================================================");

  } catch (error) {
    console.error("\n❌ An error occurred during the swap:");
    console.error(error.reason || error);
    process.exit(1);
  }
}

// --- Script Execution ---
main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});

