// This script connects to the blockchain and fetches the USDC balance for a given wallet.
// It deposits the entire USDC balance into the USDC Liquidity Pool.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getErc20Abi, getEnvVars, setupProviderAndWallet, getPositionsAbi, getLiquidityPoolFactoryAbi, getLiquidityPoolAbi } = require("./utils");
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

    const usdcContract = new ethers.Contract(env.USDC, erc20Abi, wallet);
    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);

    const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY();
    const liquidityPoolFactoryContract = new ethers.Contract(liquidityPoolFactoryAddress, liquidityPoolFactoryAbi, provider);

    try {
        // --- 1. Get USDC Balance ---
        console.log("Fetching USDC balance...");
        const usdcBalance = await usdcContract.balanceOf(wallet.address);
        const usdcDecimals = await usdcContract.decimals();

        console.log(`USDC Balance: ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC`);

        if (usdcBalance === 0n) {
            console.log("No USDC to deposit.");
            return;
        }

        // --- 2. Get Liquidity Pool Address ---
        const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(env.USDC);
        if (poolAddress === ethers.ZeroAddress) {
            console.error(`No Liquidity Pool found for USDC`);
            process.exit(1);
        }
        console.log(`USDC Pool Address: ${poolAddress}`);

        let nonce = await provider.getTransactionCount(wallet.address);

        // --- 3. Approve Pool ---
        console.log(`\nApproving Pool to spend ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC...`);
        const txApprove = await usdcContract.approve(poolAddress, usdcBalance, { nonce: nonce++ });
        await txApprove.wait();
        console.log("- Approved Pool.");

        // --- 4. Deposit ---
        console.log(`\nDepositing ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC...`);
        const liquidityPoolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, wallet);
        const txDeposit = await liquidityPoolContract.deposit(usdcBalance, wallet.address, { nonce: nonce++ });
        await txDeposit.wait();
        console.log("- Deposited.");

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
