// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It also fetches the USD price of each asset from Chainlink Price Feeds and calculates the USD value of the balances.
// Configuration is loaded from a .env file.

// Import necessary libraries
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

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
 * Loads the Chainlink Aggregator V3 Interface ABI.
 * @returns {object} The AggregatorV3Interface ABI.
 */
function getAggregatorV3Abi() {
    return [
        "function latestRoundData() view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
        "function decimals() view returns (uint8)"
    ];
}

/**
 * Fetches and displays the balance of a specific ERC20 token.
 * @param {ethers.Contract} contract The ethers.js contract instance.
 * @param {string} address The wallet address to check.
 * @param {ethers.Contract} priceFeedContract The Chainlink price feed contract instance.
 */
async function getTokenBalance(contract, address, priceFeedContract) {
    const [name, symbol, decimals, balance] = await Promise.all([
        contract.name(),
        contract.symbol(),
        contract.decimals(),
        contract.balanceOf(address)
    ]);

    const formattedBalance = ethers.formatUnits(balance, decimals);

    // Fetch the price from Chainlink
    const [, price, , ,] = await priceFeedContract.latestRoundData();
    const priceFeedDecimals = await priceFeedContract.decimals();
    
    const usdValue = (Number(formattedBalance) * Number(ethers.formatUnits(price, priceFeedDecimals))).toFixed(2);

    console.log(`- ${name} (${symbol}): ${formattedBalance} (~$${usdValue} USD)`);
}

/**
 * The main function that connects to the blockchain and fetches balances.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const envVars = process.env;

  const requiredVars = [
    "RPC_URL", "PRIVATE_KEY", "WETH", "DAI", "USDC", "WBTC",
    "ETH_USD_PRICE_FEED", "DAI_USD_PRICE_FEED", "USDC_USD_PRICE_FEED", "BTC_USD_PRICE_FEED"
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
  const ETH_USD_PRICE_FEED = ethers.getAddress(envVars.ETH_USD_PRICE_FEED);
  const DAI_USD_PRICE_FEED = ethers.getAddress(envVars.DAI_USD_PRICE_FEED);
  const USDC_USD_PRICE_FEED = ethers.getAddress(envVars.USDC_USD_PRICE_FEED);
  const BTC_USD_PRICE_FEED = ethers.getAddress(envVars.BTC_USD_PRICE_FEED);
  const PRIVATE_KEY = envVars.PRIVATE_KEY;
  const RPC_URL = envVars.RPC_URL;

  // --- Load ABIs ---
  const erc20Abi = getErc20Abi();
  const aggregatorAbi = getAggregatorV3Abi();

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

  // --- Price Feed Contract Instances ---
  const ethPriceFeed = new ethers.Contract(ETH_USD_PRICE_FEED, aggregatorAbi, provider);
  const daiPriceFeed = new ethers.Contract(DAI_USD_PRICE_FEED, aggregatorAbi, provider);
  const usdcPriceFeed = new ethers.Contract(USDC_USD_PRICE_FEED, aggregatorAbi, provider);
  const btcPriceFeed = new ethers.Contract(BTC_USD_PRICE_FEED, aggregatorAbi, provider);

  try {
    // --- Fetch and Display Balances ---
    console.log("Token Balances:");

    // ETH Balance
    const ethBalance = await provider.getBalance(wallet.address);
    const formattedEthBalance = ethers.formatEther(ethBalance);
    const [, ethPrice, , ,] = await ethPriceFeed.latestRoundData();
    const ethPriceFeedDecimals = await ethPriceFeed.decimals();
    const ethUsdValue = (Number(formattedEthBalance) * Number(ethers.formatUnits(ethPrice, ethPriceFeedDecimals))).toFixed(2);
    console.log(`- ETH: ${formattedEthBalance} (~$${ethUsdValue} USD)`);
    
    // WETH (uses ETH price feed)
    await getTokenBalance(wethContract, wallet.address, ethPriceFeed);
    // DAI
    await getTokenBalance(daiContract, wallet.address, daiPriceFeed);
    // USDC
    await getTokenBalance(usdcContract, wallet.address, usdcPriceFeed);
    // WBTC
    await getTokenBalance(wbtcContract, wallet.address, btcPriceFeed);

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
