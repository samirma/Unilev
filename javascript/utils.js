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
        "function balanceOf(address) view returns (uint256)",
        "function approve(address spender, uint256 amount) public returns (bool)",
        "function allowance(address owner, address spender) view returns (uint256)",
        "function deposit() public payable"
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
    const usdValueBigInt = await priceFeedL1Contract.getAmountInUsd(await contract.getAddress(), balance);
    const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2); // PriceFeedL1 returns USD with 18 decimals

    console.log(`  ${symbol.padEnd(6)} : ${formattedBalance.padEnd(20)} (~$ ${usdValue} USD)`);
}

/**
 * loads all environment variables and returns them as an object.
 */
function getEnvVars() {
    const envVars = process.env;
    const requiredVars = [
        "RPC_URL", "PRIVATE_KEY", "WETH", "DAI", "USDC", "WBTC", "PRICEFEEDL1_ADDRESS", "POSITIONS_ADDRESS", "UNISWAPV3HELPER_ADDRESS"
    ];

    for (const v of requiredVars) {
        if (!envVars[v]) {
            console.error(`Error: Ensure ${v} is set in ../.env`);
            process.exit(1);
        }
    }

    return {
        RPC_URL: envVars.RPC_URL,
        PRIVATE_KEY: envVars.PRIVATE_KEY,
        WETH: ethers.getAddress(envVars.WETH),
        DAI: ethers.getAddress(envVars.DAI),
        USDC: ethers.getAddress(envVars.USDC),
        WBTC: ethers.getAddress(envVars.WBTC),
        PRICEFEEDL1_ADDRESS: ethers.getAddress(envVars.PRICEFEEDL1_ADDRESS),
        POSITIONS_ADDRESS: ethers.getAddress(envVars.POSITIONS_ADDRESS),
        UNISWAPV3HELPER_ADDRESS: ethers.getAddress(envVars.UNISWAPV3HELPER_ADDRESS),
        MARKET_ADDRESS: ethers.getAddress(envVars.MARKET_ADDRESS),
        LIQUIDITYPOOLFACTORY_ADDRESS: ethers.getAddress(envVars.LIQUIDITYPOOLFACTORY_ADDRESS),
        FEEMANAGER_ADDRESS: ethers.getAddress(envVars.FEEMANAGER_ADDRESS)
    };
}

/**
 * Sets up provider and wallet.
 */
function setupProviderAndWallet(rpcUrl, privateKey) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    return { provider, wallet };
}

module.exports = {
    getAbi,
    getErc20Abi,
    getTokenBalance,
    getEnvVars,
    setupProviderAndWallet,
    calculateTokenAmountFromUsd
};

/**
 * Calculates the amount of tokens for a given USD value.
 * @param {string} tokenAddress The address of the token.
 * @param {ethers.Contract} priceFeedL1Contract The PriceFeedL1 contract.
 * @param {string} usdAmount The amount in USD (e.g., "10").
 * @returns {Promise<bigint>} The calculated token amount.
 */
async function calculateTokenAmountFromUsd(tokenAddress, priceFeedL1Contract, usdAmount) {
    const priceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(tokenAddress);
    const targetUsdValue = ethers.parseUnits(usdAmount, 18);
    // priceInUsd has 18 decimals, targetUsdValue has 18 decimals
    // we want result to have 18 decimals (or token decimals? Market usually expects 18 or match token?)
    // Market expects token amount in token decimals usually, but verify caller usage.
    // Based on `1_add_balance_pool.js`:
    // amount = (targetUsd * 10^decimals) / price

    // We need the token contract to get decimals, or assume 18 if not available here?
    // Let's pass contract or fetch it. To be truly generic, let's fetch decimals here.
    // However, to keep it simple and avoid creating provider here, maybe pass decimals or contract?
    // Let's rely on standard ERC20 generic call if we have provider, but we only have address.
    // Let's act simple: Assume caller handles decimals or we return amount in 18 decimals if standard?
    // Wait, `1_add_balance_pool.js` gets decimals.
    // Let's update signature to take decimals or a provider/contract.
    // Easier: take tokenDecimals as arg.

    // Re-reading `1_add_balance_pool.js`:
    // tokenAmountToDeposit = (targetUsdValue * BigInt(10n ** tokenDecimals)) / priceInUsd;

    return { targetUsdValue, priceInUsd }; // Helper might be too specific if we don't pass decimals.
}

// Actually, let's make it robust.
async function calculateTokenAmountFromUsd(contract, priceFeedL1Contract, usdAmount) {
    const decimals = await contract.decimals();
    const priceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(await contract.getAddress());
    const targetUsdValue = ethers.parseUnits(usdAmount, 18);
    return (targetUsdValue * BigInt(10n ** decimals)) / priceInUsd;
}
