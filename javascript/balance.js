// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It now uses the PriceFeedL1 contract to fetch the USD price of each asset and calculate the USD value of the balances.
// Configuration is loaded from a .env file.

// Import necessary libraries
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
        "function name() view returns (string)",
        "function symbol() view returns (string)",
        "function decimals() view returns (uint8)",
        "function balanceOf(address) view returns (uint256)"
    ];
}

/**
 * Fetches and displays the balance of a specific ERC20 token using PriceFeedL1.
 * @param {ethers.Contract} contract The ethers.js contract instance.
 * @param {string} address The wallet address to check.
 * @param {ethers.Contract} priceFeedL1Contract The PriceFeedL1 contract instance.
 */
async function getTokenBalance(contract, address, priceFeedL1Contract) {
    const [name, symbol, decimals, balance] = await Promise.all([
        contract.name(),
        contract.symbol(),
        contract.decimals(),
        contract.balanceOf(address)
    ]);

    const formattedBalance = ethers.formatUnits(balance, decimals);

    // Fetch the USD value from the PriceFeedL1 contract
    const usdValueBigInt = await priceFeedL1Contract.getAmountInUSD(await contract.getAddress(), balance);
    const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2); // PriceFeedL1 returns USD with 18 decimals

    console.log(`- ${name} (${symbol}): ${formattedBalance} (~$${usdValue} USD)`);
}

/**
 * The main function that connects to the blockchain and fetches balances.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const envVars = process.env;

  const requiredVars = [
    "RPC_URL", "PRIVATE_KEY", "WETH", "DAI", "USDC", "WBTC", "PRICEFEEDL1_ADDRESS"
  ];

  for (const v of requiredVars) {
      if (!envVars[v]) {
          console.error(`Error: Ensure ${v} is set in ../.env`);
          process.exit(1);
      }
  }

  // --- Correctly Checksum Addresses ---
  const WETH = ethers.getAddress(envVars.WETH);
  const DAI = ethers.getAddress(envVars.DAI);
  const USDC = ethers.getAddress(envVars.USDC);
  const WBTC = ethers.getAddress(envVars.WBTC);
  const PRICEFEEDL1_ADDRESS = ethers.getAddress(envVars.PRICEFEEDL1_ADDRESS);
  const PRIVATE_KEY = envVars.PRIVATE_KEY;
  const RPC_URL = envVars.RPC_URL;

  // --- Load ABIs ---
  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");

  // --- Provider & Wallet Setup ---
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  console.log(`Fetching balances for wallet: ${wallet.address}`);
  console.log("----------------------------------------------------\n");

  // --- Contract Instances ---
  const wethContract = new ethers.Contract(WETH, erc20Abi, provider);
  const daiContract = new ethers.Contract(DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(WBTC, erc20Abi, provider);

  // --- Price Feed Contract Instance ---
  const priceFeedL1Contract = new ethers.Contract(PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

  try {
    // --- Fetch and Display Balances ---
    console.log("Token Balances:");

    // ETH Balance
    const ethBalance = await provider.getBalance(wallet.address);
    const formattedEthBalance = ethers.formatEther(ethBalance);
    // Use WETH address to get the price of ETH from PriceFeedL1
    const ethUsdValueBigInt = await priceFeedL1Contract.getAmountInUSD(WETH, ethBalance);
    const ethUsdValue = parseFloat(ethers.formatUnits(ethUsdValueBigInt, 18)).toFixed(2);
    console.log(`- ETH: ${formattedEthBalance} (~$${ethUsdValue} USD)`);

    // Fetch ERC20 token balances
    await getTokenBalance(wethContract, wallet.address, priceFeedL1Contract);
    await getTokenBalance(daiContract, wallet.address, priceFeedL1Contract);
    await getTokenBalance(usdcContract, wallet.address, priceFeedL1Contract);
    await getTokenBalance(wbtcContract, wallet.address, priceFeedL1Contract);

    console.log("\n====================================================");
    console.log("✅ Balance check complete!");
    console.log("====================================================");

  } catch (error) {
    console.error("\n❌ An error occurred while fetching balances:");
    console.error(error.reason || error);
    process.exit(1);
  }
}

// --- Script Execution ---
main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});