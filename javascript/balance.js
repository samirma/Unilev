// This script connects to the blockchain and fetches the balance of ETH and supported tokens for a given wallet.
// It now uses the PriceFeedL1 contract to fetch the USD price of each asset and calculate the USD value of the balances.
// Configuration is loaded from a .env file and supported_tokens.json.

const { ethers } = require("ethers")
const {
    getErc20Abi,
    getTokenBalance,
    getEnvVars,
    setupProviderAndWallet,
    getPriceFeedL1Abi,
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

function getTokenContracts(supportedTokens, erc20Abi, provider) {
    const contracts = {}
    for (const [symbol, address] of Object.entries(supportedTokens)) {
        if (symbol !== "wrapper") {
            contracts[symbol] = new ethers.Contract(address, erc20Abi, provider)
        }
    }
    return contracts
}

async function logWalletBalances(env, provider, wallet) {
    logHeader("💰 WALLET BALANCES", `Address: ${wallet.address}`)

    const supportedTokens = getSupportedTokens()
    if (!supportedTokens) {
        console.error("Could not load supported tokens")
        return
    }

    const erc20Abi = getErc20Abi()
    const priceFeedL1Abi = getPriceFeedL1Abi()
    const priceFeedL1Contract = new ethers.Contract(
        env.PRICEFEEDL1_ADDRESS,
        priceFeedL1Abi,
        provider
    )

    const ethBalance = await provider.getBalance(wallet.address)
    const formattedEthBalance = ethers.formatEther(ethBalance)
    const wethAddress = supportedTokens.WETH
    const ethUsdValueBigInt = await priceFeedL1Contract.getAmountInUsd(wethAddress, ethBalance)
    const ethUsdValue = parseFloat(ethers.formatUnits(ethUsdValueBigInt, 18)).toFixed(2)
    console.log(`  ETH    : ${formattedEthBalance.padEnd(20)} (~$ ${ethUsdValue} USD)`)

    const tokenContracts = getTokenContracts(supportedTokens, erc20Abi, provider)
    for (const [symbol, contract] of Object.entries(tokenContracts)) {
        await getTokenBalance(contract, wallet.address, priceFeedL1Contract)
    }
}

async function logPositionBalances(env, provider, wallet) {
    const supportedTokens = getSupportedTokens()
    if (!supportedTokens) {
        console.error("Could not load supported tokens")
        return
    }

    const erc20Abi = getErc20Abi()
    const priceFeedL1Abi = getPriceFeedL1Abi()
    const priceFeedL1Contract = new ethers.Contract(
        env.PRICEFEEDL1_ADDRESS,
        priceFeedL1Abi,
        provider
    )

    const tokenContracts = getTokenContracts(supportedTokens, erc20Abi, provider)

    logHeader("📉 POSITION CONTRACT BALANCES", `Address: ${env.POSITIONS_ADDRESS}`)
    for (const [symbol, contract] of Object.entries(tokenContracts)) {
        await getTokenBalance(contract, env.POSITIONS_ADDRESS, priceFeedL1Contract)
    }
}

async function logPoolBalances(env, provider) {
    const supportedTokens = getSupportedTokens()
    if (!supportedTokens) {
        console.error("Could not load supported tokens")
        return
    }

    const erc20Abi = getErc20Abi()
    const priceFeedL1Abi = getPriceFeedL1Abi()
    const positionsAbi = getPositionsAbi()
    const liquidityPoolFactoryAbi = getLiquidityPoolFactoryAbi()
    const liquidityPoolAbi = getLiquidityPoolAbi()

    const tokenContracts = getTokenContracts(supportedTokens, erc20Abi, provider)

    const priceFeedL1Contract = new ethers.Contract(
        env.PRICEFEEDL1_ADDRESS,
        priceFeedL1Abi,
        provider
    )
    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider)

    const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY()
    const liquidityPoolFactoryContract = new ethers.Contract(
        liquidityPoolFactoryAddress,
        liquidityPoolFactoryAbi,
        provider
    )

    logHeader("🏊 LIQUIDITY POOLS")
    const tokens = Object.entries(tokenContracts).map(([symbol, contract]) => ({
        contract,
        name: symbol,
    }))

    for (const token of tokens) {
        const tokenAddress = await token.contract.getAddress()
        const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(
            tokenAddress
        )

        if (poolAddress !== ethers.ZeroAddress) {
            const poolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, provider)
            const rawTotalAsset = await poolContract.rawTotalAsset()
            const decimals = await token.contract.decimals()
            const formattedAsset = ethers.formatUnits(rawTotalAsset, decimals)

            let usdValue = "0.00"
            try {
                const usdValueBigInt = await priceFeedL1Contract.getAmountInUsd(
                    tokenAddress,
                    rawTotalAsset
                )
                usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2)
            } catch (e) {
                // Price feed not available for this token
            }

            console.log(
                `  ${token.name.padEnd(6)} : ${formattedAsset.padEnd(20)} (~$ ${usdValue} USD)`
            )
        } else {
            console.log(`  ${token.name.padEnd(6)} : Pool Not Found`)
        }
    }
}

async function logTreasureBalances(env, provider) {
    const supportedTokens = getSupportedTokens()
    if (!supportedTokens) {
        console.error("Could not load supported tokens")
        return
    }

    const erc20Abi = getErc20Abi()
    const priceFeedL1Abi = getPriceFeedL1Abi()
    const positionsAbi = getPositionsAbi()

    const priceFeedL1Contract = new ethers.Contract(
        env.PRICEFEEDL1_ADDRESS,
        priceFeedL1Abi,
        provider
    )
    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider)

    const treasureAddress = await positionsContract.treasure()

    logHeader("💎 TREASURE CONTRACT BALANCES", `Address: ${treasureAddress}`)

    const ethBalance = await provider.getBalance(treasureAddress)
    const formattedEthBalance = ethers.formatEther(ethBalance)
    const wethAddress = supportedTokens.WETH
    const ethUsdValueBigInt = await priceFeedL1Contract.getAmountInUsd(wethAddress, ethBalance)
    const ethUsdValue = parseFloat(ethers.formatUnits(ethUsdValueBigInt, 18)).toFixed(2)
    console.log(`  ETH    : ${formattedEthBalance.padEnd(20)} (~$ ${ethUsdValue} USD)`)

    const tokenContracts = getTokenContracts(supportedTokens, erc20Abi, provider)
    for (const [symbol, contract] of Object.entries(tokenContracts)) {
        await getTokenBalance(contract, treasureAddress, priceFeedL1Contract)
    }
}

async function logBalances(env, provider, wallet) {
    try {
        await logWalletBalances(env, provider, wallet)
        await logPositionBalances(env, provider, wallet)
        await logTreasureBalances(env, provider)
        await logPoolBalances(env, provider)
    } catch (error) {
        console.error("\n❌ An error occurred while fetching balances:")
        console.error(error.reason || error)
        throw error
    }
}

async function main() {
    const env = getEnvVars()
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY)
    await logBalances(env, provider, wallet)
}

if (require.main === module) {
    main().catch((error) => {
        console.error("An unexpected error occurred in the main execution:", error)
        process.exit(1)
    })
}

module.exports = {
    logBalances,
    logWalletBalances,
    logPositionBalances,
    logPoolBalances,
    logTreasureBalances,
}
