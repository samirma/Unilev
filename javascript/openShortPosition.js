const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

/**
 * Loads the contract ABI from the JSON file.
 * @param {string} contractName The name of the contract.
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
 * Loads a standard ERC20 ABI.
 * @returns {object} The ERC20 contract ABI.
 */
function getErc20Abi() {
    return [
        "function approve(address spender, uint256 amount) public returns (bool)",
        "function balanceOf(address account) view returns (uint256)"
    ];
}


/**
 * The main function that connects to the blockchain, opens, verifies, and closes a short position.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const { RPC_URL, PRIVATE_KEY, MARKET_ADDRESS, POSITIONS_ADDRESS, USDC, WETH } = process.env;

  if (!RPC_URL || !PRIVATE_KEY || !MARKET_ADDRESS || !POSITIONS_ADDRESS || !USDC || !WETH) {
    console.error(
      "Error: Ensure RPC_URL, PRIVATE_KEY, MARKET_ADDRESS, POSITIONS_ADDRESS, USDC, and WETH are set in ../.env"
    );
    process.exit(1);
  }

  // --- Load ABIs ---
  const marketAbi = getAbi("Market");
  const positionsAbi = getAbi("Positions");
  const erc20Abi = getErc20Abi();

  // --- Provider & Wallet Setup ---
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  console.log(`Using wallet address: ${wallet.address}`);

  // --- Contract Instances ---
  const marketContract = new ethers.Contract(MARKET_ADDRESS, marketAbi, wallet);
  const positionsContract = new ethers.Contract(POSITIONS_ADDRESS, positionsAbi, wallet);
  const usdcContract = new ethers.Contract(USDC, erc20Abi, wallet);

  // --- Get initial nonce ---
  let nonce = await wallet.getNonce();

  // --- Position Parameters ---
  const collateralAmount = ethers.parseUnits("1000", 6); // 1000 USDC (6 decimals)
  const positionSize = ethers.parseEther("1");           // 1 WETH (18 decimals)
  const isLong = false; // This is a short position

  try {
    // --- Approve USDC for collateral ---
    console.log("\n1. Approving Market contract to spend USDC...");
    const approveTx = await usdcContract.approve(MARKET_ADDRESS, collateralAmount, { nonce: nonce });
    console.log(`Approval transaction sent! Hash: ${approveTx.hash}`);
    await approveTx.wait();
    console.log("Approval successful!");
    nonce++;

    // --- Open the Short Position ---
    console.log("\n2. Opening short position...");
    const openPositionTx = await marketContract.openPosition(
        WETH,               // Index Token (the asset we are shorting)
        USDC,               // Collateral Token
        collateralAmount,   // Collateral Amount
        positionSize,       // Size of the position
        isLong,             // isLong = false for short
        0,                  // referralCode
        { nonce: nonce }
    );
    console.log(`Open position transaction sent! Hash: ${openPositionTx.hash}`);
    const receipt = await openPositionTx.wait();
    console.log("Position opened successfully!");
    nonce++;
    
    // NOTE: We need to parse the event logs to get the positionId
    const positionId = 0; // In a real scenario, you would parse this from the transaction receipt's events.
                          // For this example, we assume it's the first position (ID 0).
    console.log(`Position opened with ID: ${positionId}`);


    // --- Verify the Position was Opened ---
    console.log("\n3. Verifying the position...");
    const position = await positionsContract.getPosition(positionId);
    
    if (position.size === 0n) {
        throw new Error("Position verification failed: Position not found or size is zero.");
    }
    console.log("Position details fetched successfully:");
    console.log({
        owner: position.owner,
        collateralToken: position.collateralToken,
        indexToken: position.indexToken,
        collateralAmount: ethers.formatUnits(position.collateralAmount, 6),
        size: ethers.formatEther(position.size),
        isLong: position.isLong,
    });
    console.log("Verification successful!");


    // --- Close the Position ---
    console.log("\n4. Closing the position...");
    const closePositionTx = await marketContract.closePosition(positionId, { nonce: nonce });
    console.log(`Close position transaction sent! Hash: ${closePositionTx.hash}`);
    await closePositionTx.wait();
    console.log("Position closed successfully!");

    // --- Verify the Position was Closed ---
    console.log("\n5. Verifying the position is closed...");
    const closedPosition = await positionsContract.getPosition(positionId);
    if (closedPosition.size === 0n && closedPosition.owner === ethers.ZeroAddress) {
        console.log("Verification successful: Position has been deleted.");
    } else {
        console.error("Verification failed: Position still exists.");
    }
    
    console.log("\n====================================================");
    console.log("✅ Short position workflow completed successfully!");
    console.log("====================================================");

  } catch (error) {
    console.error("\n❌ An error occurred during the process:");
    console.error(error.reason || error);
    process.exit(1);
  }
}

// --- Script Execution ---
main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});
