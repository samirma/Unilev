// This script initializes a wallet by swapping ETH for approximately $100 worth of WETH, DAI, USDC, and WBTC.
// It dynamically calculates the required amounts based on live price data from Chainlink.
// It handles ETH wrapping and token approvals before executing the swaps via the UniswapV3Helper contract.

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
 * Loads a standard ERC20 ABI for approvals and balance checks.
 * @returns {object} The ERC20 contract ABI.
 */
function getErc20Abi() {
    return [
        "function approve(address spender, uint256 amount) public returns (bool)",
        "function allowance(address owner, address spender) view returns (uint256)",
        "function balanceOf(address account) view returns (uint256)",
        "function decimals() view returns (uint8)"
    ];
}

/**
 * Loads an ABI for a WETH contract.
 * @returns {object} The WETH ABI.
 */
function getWethAbi() {
    return [
        ...getErc20Abi(),
        "function deposit() public payable",
        "function withdraw(uint wad) public"
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
 * The main function that connects to the blockchain and executes the swaps.
 */
async function main() {
  // --- Environment Variable Setup & Validation ---
  const envVars = process.env;
  const requiredVars = [
    "RPC_URL", "PRIVATE_KEY", "UNISWAPV3HELPER_ADDRESS", "WETH", "DAI", "USDC", "WBTC",
    "ETH_USD_PRICE_FEED", "DAI_USD_PRICE_FEED", "USDC_USD_PRICE_FEED", "BTC_USD_PRICE_FEED"
  ];

  for (const v of requiredVars) {
    if (!envVars[v]) {
      console.error(`Error: Ensure ${v} is set in ../.env`);
      process.exit(1);
    }
  }

  // --- Correctly Checksum Addresses ---
  const { PRIVATE_KEY, RPC_URL } = envVars;
  const UNISWAPV3HELPER_ADDRESS = ethers.getAddress(envVars.UNISWAPV3HELPER_ADDRESS);
  const WETH = ethers.getAddress(envVars.WETH);
  const DAI = ethers.getAddress(envVars.DAI);
  const USDC = ethers.getAddress(envVars.USDC);
  const WBTC = ethers.getAddress(envVars.WBTC);
  const ETH_USD_PRICE_FEED = ethers.getAddress(envVars.ETH_USD_PRICE_FEED);
  const DAI_USD_PRICE_FEED = ethers.getAddress(envVars.DAI_USD_PRICE_FEED);
  const USDC_USD_PRICE_FEED = ethers.getAddress(envVars.USDC_USD_PRICE_FEED);
  const BTC_USD_PRICE_FEED = ethers.getAddress(envVars.BTC_USD_PRICE_FEED);

  // --- Load ABIs ---
  const uniswapV3HelperAbi = getAbi("UniswapV3Helper");
  const wethAbi = getWethAbi();
  const aggregatorAbi = getAggregatorV3Abi();
  const erc20Abi = getErc20Abi();

  // --- Provider & Wallet Setup ---
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  console.log(`Using wallet address: ${wallet.address}`);

  // --- Contract Instances ---
  const uniswapHelper = new ethers.Contract(UNISWAPV3HELPER_ADDRESS, uniswapV3HelperAbi, wallet);
  const wethContract = new ethers.Contract(WETH, wethAbi, wallet);

  // --- Price Feed Instances ---
  const ethPriceFeed = new ethers.Contract(ETH_USD_PRICE_FEED, aggregatorAbi, provider);
  
  const tokensToSwap = [
      { name: "WETH", address: WETH, priceFeed: ethPriceFeed, poolFee: 0 }, // Pool fee is not used for wrapping
      { name: "DAI", address: DAI, priceFeed: new ethers.Contract(DAI_USD_PRICE_FEED, aggregatorAbi, provider), poolFee: 500 },
      { name: "USDC", address: USDC, priceFeed: new ethers.Contract(USDC_USD_PRICE_FEED, aggregatorAbi, provider), poolFee: 500 },
      { name: "WBTC", address: WBTC, priceFeed: new ethers.Contract(BTC_USD_PRICE_FEED, aggregatorAbi, provider), poolFee: 3000 },
  ];

  try {
    let nonce = await wallet.getNonce();

    // Get current ETH price
    const [, ethPriceAnswer, , ,] = await ethPriceFeed.latestRoundData();
    const ethPriceFeedDecimals = await ethPriceFeed.decimals();
    const ethPrice = Number(ethers.formatUnits(ethPriceAnswer, ethPriceFeedDecimals));
    console.log(`Current ETH Price: $${ethPrice.toFixed(2)}`);

    for (const token of tokensToSwap) {
        console.log(`\n----------------- Acquiring ${token.name} -----------------`);
        
        const targetUsdValue = 100;

        if (token.name === "WETH") {
            const amountToWrap = ethers.parseEther((targetUsdValue / ethPrice).toString());
            console.log(`Wrapping ${ethers.formatEther(amountToWrap)} ETH for ~$${targetUsdValue} of WETH...`);
            const wrapTx = await wethContract.deposit({ value: amountToWrap, nonce: nonce });
            console.log(`Wrapping transaction sent! Hash: ${wrapTx.hash}`);
            await wrapTx.wait();
            console.log(`Successfully acquired ~$${targetUsdValue} of WETH!`);
            nonce++;
        } else {
            // 1. Calculate amountOut for $100 USD
            const tokenContract = new ethers.Contract(token.address, erc20Abi, provider);
            const tokenDecimals = await tokenContract.decimals();
            const [, tokenPriceAnswer, , ,] = await token.priceFeed.latestRoundData();
            const tokenPriceFeedDecimals = await token.priceFeed.decimals();
            const tokenPrice = Number(ethers.formatUnits(tokenPriceAnswer, tokenPriceFeedDecimals));
    
            const amountOut = targetUsdValue / tokenPrice;
            const amountOutWei = ethers.parseUnits(amountOut.toFixed(Number(tokenDecimals)), tokenDecimals);
    
            console.log(`Targeting ~$${targetUsdValue} worth of ${token.name}, which is ${amountOut.toFixed(6)} ${token.name}`);
            
            // 2. Calculate required ETH (amountIn) with a 5% slippage buffer
            const amountInEth = targetUsdValue / ethPrice * 1.05; // 5% slippage
            const amountInMaxWei = ethers.parseEther(amountInEth.toString());
            console.log(`Max ETH to spend: ${ethers.formatEther(amountInMaxWei)}`);
    
            // 3. Wrap ETH if necessary
            const wethBalance = await wethContract.balanceOf(wallet.address);
            if (wethBalance < amountInMaxWei) {
                const wrapAmount = amountInMaxWei - wethBalance;
                console.log(`Insufficient WETH. Wrapping ${ethers.formatEther(wrapAmount)} ETH...`);
                const wrapTx = await wethContract.deposit({ value: wrapAmount, nonce: nonce });
                console.log(`Wrapping transaction sent! Hash: ${wrapTx.hash}`);
                await wrapTx.wait();
                console.log("Wrapping successful!");
                nonce++;
            }
            
            // 4. Approve WETH for the helper contract
            const allowance = await wethContract.allowance(wallet.address, UNISWAPV3HELPER_ADDRESS);
            if (allowance < amountInMaxWei) {
                console.log("Approving UniswapV3Helper to spend WETH...");
                const approveTx = await wethContract.approve(UNISWAPV3HELPER_ADDRESS, amountInMaxWei, { nonce: nonce });
                console.log(`Approval transaction sent! Hash: ${approveTx.hash}`);
                await approveTx.wait();
                console.log("Approval successful!");
                nonce++;
            }
    
            // 5. Perform the swap
            console.log(`Executing swap for ${token.name}...`);
            const swapTx = await uniswapHelper.swapExactOutputSingle(
                WETH,
                token.address,
                token.poolFee,
                amountOutWei,
                amountInMaxWei,
                { nonce: nonce }
            );
            console.log(`Swap transaction sent! Hash: ${swapTx.hash}`);
            await swapTx.wait();
            console.log(`Successfully swapped for ${token.name}!`);
            nonce++;
        }
    }
    
    console.log("\n====================================================");
    console.log("✅ All swaps completed successfully!");
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

