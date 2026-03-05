// This script redeems liquidity pool shares for the underlying assets.
// It shows current LP balances and allows redeeming all or specific amounts.
// Configuration is loaded from a .env file and supported_tokens.json.

const { ethers } = require("ethers")
const {
    getErc20Abi,
    getEnvVars,
    setupProviderAndWallet,
    getPositionsAbi,
    getLiquidityPoolFactoryAbi,
    getLiquidityPoolAbi,
    getSupportedTokens,
} = require("./utils")

function logHeader(title, subtitle = "") {
    console.log("\n========================================================")
    console.log(` ${title}`)
    if (subtitle) console.log(` ${subtitle}`)
    console.log("========================================================")
}

/**
 * Fetches and displays LP share balances for the wallet across all pools
 * @param {Object} env - Environment variables
 * @param {ethers.Provider} provider - Ethers provider
 * @param {string} walletAddress - Wallet address to check
 * @returns {Array} Array of pool info objects with balances
 */
async function getLiquidityPoolBalances(env, provider, walletAddress) {
    const supportedTokens = getSupportedTokens()
    if (!supportedTokens) {
        console.error("Could not load supported tokens")
        return []
    }

    const erc20Abi = getErc20Abi()
    const positionsAbi = getPositionsAbi()
    const liquidityPoolFactoryAbi = getLiquidityPoolFactoryAbi()
    const liquidityPoolAbi = getLiquidityPoolAbi()

    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider)

    const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY()
    const liquidityPoolFactoryContract = new ethers.Contract(
        liquidityPoolFactoryAddress,
        liquidityPoolFactoryAbi,
        provider
    )

    const poolsWithBalances = []

    logHeader("🏊 LIQUIDITY POOL SHARES", `Address: ${walletAddress}`)

    for (const [symbol, tokenAddress] of Object.entries(supportedTokens)) {
        if (symbol === "wrapper") continue

        const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(tokenAddress)

        if (poolAddress === ethers.ZeroAddress) {
            console.log(`  ${symbol.padEnd(6)} : No Pool`)
            continue
        }

        const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider)
        const poolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, provider)

        const [decimals, shareBalance, assetBalance, totalSupply, totalAssets] = await Promise.all([
            tokenContract.decimals(),
            poolContract.balanceOf(walletAddress),
            poolContract.convertToAssets(await poolContract.balanceOf(walletAddress)),
            poolContract.totalSupply(),
            poolContract.totalAssets(),
        ])

        const formattedShares = ethers.formatUnits(shareBalance, decimals)
        const formattedAssets = ethers.formatUnits(assetBalance, decimals)

        console.log(`  ${symbol.padEnd(6)} : ${formattedShares.padEnd(20)} shares (~${formattedAssets} ${symbol})`)
        console.log(`         Pool: ${poolAddress}`)

        if (shareBalance > 0n) {
            poolsWithBalances.push({
                symbol,
                tokenAddress,
                poolAddress,
                shareBalance,
                assetBalance,
                decimals,
                totalSupply,
                totalAssets,
                poolContract,
                tokenContract,
            })
        }
    }

    return poolsWithBalances
}

/**
 * Redeems all shares from a liquidity pool
 * @param {Object} poolInfo - Pool info object
 * @param {ethers.Wallet} wallet - Ethers wallet
 * @param {number} nonce - Transaction nonce
 * @returns {Promise<number>} Updated nonce
 */
async function redeemAllShares(poolInfo, wallet, nonce) {
    const { symbol, poolContract, shareBalance, decimals, poolAddress } = poolInfo

    console.log(`\n  Redeeming all shares from ${symbol} pool...`)
    console.log(`  Shares to redeem: ${ethers.formatUnits(shareBalance, decimals)}`)

    const tx = await poolContract.redeem(shareBalance, wallet.address, wallet.address, { nonce })
    const receipt = await tx.wait()

    console.log(`  ✅ Redeemed successfully! Tx: ${receipt.hash}`)
    return nonce + 1
}

/**
 * Redeems a specific amount of shares from a liquidity pool
 * @param {Object} poolInfo - Pool info object
 * @param {ethers.Wallet} wallet - Ethers wallet
 * @param {bigint} sharesToRedeem - Amount of shares to redeem
 * @param {number} nonce - Transaction nonce
 * @returns {Promise<number>} Updated nonce
 */
async function redeemShares(poolInfo, wallet, sharesToRedeem, nonce) {
    const { symbol, poolContract, decimals, poolAddress } = poolInfo

    console.log(`\n  Redeeming ${ethers.formatUnits(sharesToRedeem, decimals)} shares from ${symbol} pool...`)

    const tx = await poolContract.redeem(sharesToRedeem, wallet.address, wallet.address, { nonce })
    const receipt = await tx.wait()

    console.log(`  ✅ Redeemed successfully! Tx: ${receipt.hash}`)
    return nonce + 1
}

/**
 * Withdraws a specific amount of assets from a liquidity pool
 * @param {Object} poolInfo - Pool info object
 * @param {ethers.Wallet} wallet - Ethers wallet
 * @param {bigint} assetsToWithdraw - Amount of assets to withdraw
 * @param {number} nonce - Transaction nonce
 * @returns {Promise<number>} Updated nonce
 */
async function withdrawAssets(poolInfo, wallet, assetsToWithdraw, nonce) {
    const { symbol, poolContract, decimals, poolAddress } = poolInfo

    console.log(`\n  Withdrawing ${ethers.formatUnits(assetsToWithdraw, decimals)} ${symbol} from pool...`)

    const tx = await poolContract.withdraw(assetsToWithdraw, wallet.address, wallet.address, { nonce })
    const receipt = await tx.wait()

    console.log(`  ✅ Withdrawn successfully! Tx: ${receipt.hash}`)
    return nonce + 1
}

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars()
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY)

    console.log(`\nLiquidity Pool Redeem Script`)
    console.log(`Wallet: ${wallet.address}`)
    console.log("----------------------------------------------------\n")

    try {
        // --- Get LP Balances ---
        const poolsWithBalances = await getLiquidityPoolBalances(env, provider, wallet.address)

        if (poolsWithBalances.length === 0) {
            console.log("\n  No LP shares found to redeem.")
            process.exit(0)
        }

        // --- Process Redemptions ---
        console.log("\n----------------------------------------------------")
        console.log("Processing redemptions...")

        let nonce = await provider.getTransactionCount(wallet.address)

        // Redeem all shares from all pools
        // You can modify this logic to redeem specific amounts or specific pools
        for (const poolInfo of poolsWithBalances) {
            // Connect pool contract with wallet for transactions
            const liquidityPoolAbi = getLiquidityPoolAbi()
            const poolContractWithSigner = new ethers.Contract(
                poolInfo.poolAddress,
                liquidityPoolAbi,
                wallet
            )
            poolInfo.poolContract = poolContractWithSigner

            // Option 1: Redeem all shares
            nonce = await redeemAllShares(poolInfo, wallet, nonce)

            // Option 2: Redeem specific amount of shares
            // const sharesToRedeem = ethers.parseUnits("1", poolInfo.decimals) // 1 share
            // nonce = await redeemShares(poolInfo, wallet, sharesToRedeem, nonce)

            // Option 3: Withdraw specific amount of assets
            // const assetsToWithdraw = ethers.parseUnits("1", poolInfo.decimals) // 1 asset
            // nonce = await withdrawAssets(poolInfo, wallet, assetsToWithdraw, nonce)
        }

        // --- Final Balances ---
        console.log("\n----------------------------------------------------")
        console.log("Final LP Balances:")
        await getLiquidityPoolBalances(env, provider, wallet.address)

        console.log("\n✅ All redemptions completed successfully!")
    } catch (error) {
        console.error("\n❌ An error occurred while redeeming:")
        console.error(error.reason || error.message || error)
        process.exit(1)
    }
}

// Export functions for use as a module
module.exports = {
    getLiquidityPoolBalances,
    redeemAllShares,
    redeemShares,
    withdrawAssets,
}

// Run main if called directly
if (require.main === module) {
    main().catch((error) => {
        console.error("An unexpected error occurred:", error)
        process.exit(1)
    })
}
