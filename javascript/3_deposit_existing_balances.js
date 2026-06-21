// This script connects to the blockchain and fetches the balance of each supported token in the wallet.
// It then deposits the entire balance of each token into its respective Liquidity Pool.
// Configuration is loaded from a .env file and supported_tokens.json.

const { ethers } = require("ethers");
const {
    getErc20Abi,
    getEnvVars,
    setupProviderAndWallet,
    getPositionsAbi,
    getLiquidityPoolFactoryAbi,
    getLiquidityPoolAbi,
    getSupportedTokens,
} = require("./utils");
const { logPoolBalances } = require("./balance");

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars();
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

    console.log(`Using wallet: ${wallet.address}`);
    console.log("----------------------------------------------------\n");

    // --- Contract Instances ---
    const erc20Abi = getErc20Abi();
    const positionsAbi = getPositionsAbi();
    const liquidityPoolFactoryAbi = getLiquidityPoolFactoryAbi();
    const liquidityPoolAbi = getLiquidityPoolAbi();

    const supportedTokens = getSupportedTokens();
    if (!supportedTokens) {
        console.error("Could not load supported tokens");
        process.exit(1);
    }

    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);
    const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY();
    const liquidityPoolFactoryContract = new ethers.Contract(
        liquidityPoolFactoryAddress,
        liquidityPoolFactoryAbi,
        provider
    );

    try {
        let nonce = await provider.getTransactionCount(wallet.address);

        for (const [symbol, address] of Object.entries(supportedTokens)) {
            if (symbol === "wrapper") continue;

            console.log(`\n----------------------------------------------------`);
            console.log(`Checking balance for ${symbol} (${address})...`);

            const tokenContract = new ethers.Contract(address, erc20Abi, wallet);
            const balance = await tokenContract.balanceOf(wallet.address);
            const decimals = await tokenContract.decimals();

            console.log(`Wallet Balance: ${ethers.formatUnits(balance, decimals)} ${symbol}`);

            if (balance === 0n) {
                console.log(`- Skipping ${symbol}: balance is 0.`);
                continue;
            }

            const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(address);
            if (poolAddress === ethers.ZeroAddress) {
                console.log(`- Skipping ${symbol}: no Liquidity Pool found.`);
                continue;
            }
            console.log(`- Liquidity Pool: ${poolAddress}`);

            // Check current allowance
            const currentAllowance = await tokenContract.allowance(wallet.address, poolAddress);
            if (currentAllowance < balance) {
                console.log(`- Approving Pool to spend ${ethers.formatUnits(balance, decimals)} ${symbol}...`);
                const txApprove = await tokenContract.approve(poolAddress, balance, { nonce: nonce++ });
                await txApprove.wait();
                console.log(`- Approved.`);
            } else {
                console.log(`- Sufficient allowance already exists.`);
            }

            console.log(`- Depositing ${ethers.formatUnits(balance, decimals)} ${symbol} to Pool...`);
            const liquidityPoolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, wallet);
            const txDeposit = await liquidityPoolContract.deposit(balance, wallet.address, { nonce: nonce++ });
            await txDeposit.wait();
            console.log(`- Deposit successful!`);
        }

        // --- Fetch and Display Balances ---
        console.log("\n----------------------------------------------------");
        console.log("Final Pool Balances:");
        await logPoolBalances(env, provider, wallet);

    } catch (error) {
        console.error("\n❌ An error occurred while processing:");
        console.error(error);
        process.exit(1);
    }
}

main().catch((error) => {
    console.error("An unexpected error occurred in the main execution:", error);
    process.exit(1);
});
