const { ethers } = require("ethers")
const fs = require("fs")
const path = require("path")
require("dotenv").config({ path: path.resolve(__dirname, "../.env") })

function getSupportedTokens() {
    const supportedTokensPath = path.resolve(__dirname, "../supported_tokens.json")
    try {
        const data = fs.readFileSync(supportedTokensPath, "utf8")
        const tokens = JSON.parse(data)
        const result = {}
        for (const [key, value] of Object.entries(tokens)) {
            result[key] = ethers.getAddress(value)
        }
        return result
    } catch (error) {
        console.error(`Error loading supported_tokens.json:`, error.message)
        return null
    }
}

/**
 * Loads the contract ABI from the JSON file.
 * @param {string} contractName The name of the contract.
 * @returns {object} The contract ABI.
 */
function getAbi(contractName) {
    try {
        const abiPath = path.resolve(__dirname, `../out/${contractName}.sol/${contractName}.json`)
        const abiFile = fs.readFileSync(abiPath, "utf8")
        return JSON.parse(abiFile).abi
    } catch (error) {
        console.error(`Error loading contract ABI for ${contractName}:`, error.message)
        console.error(
            "Please ensure the contract has been compiled and the ABI file is in the correct path."
        )
        process.exit(1)
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
        "function deposit() public payable",
    ]
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
        contract.balanceOf(address),
    ])

    const formattedBalance = ethers.formatUnits(balance, decimals)

    // Fetch the USD value from the PriceFeedL1 contract
    const usdValueBigInt = await priceFeedL1Contract.getAmountInUsd(
        await contract.getAddress(),
        balance
    )
    const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2) // PriceFeedL1 returns USD with 18 decimals

    console.log(`  ${symbol.padEnd(6)} : ${formattedBalance.padEnd(20)} (~$ ${usdValue} USD)`)
}

/**
 * loads all environment variables and returns them as an object.
 */
function getEnvVars() {
    const envVars = process.env
    const requiredVars = [
        "RPC_URL",
        "PRIVATE_KEY",
        "PRICEFEEDL1_ADDRESS",
        "POSITIONS_ADDRESS",
        "UNISWAPV3HELPER_ADDRESS",
    ]

    for (const v of requiredVars) {
        if (!envVars[v]) {
            console.error(`Error: Ensure ${v} is set in ../.env`)
            process.exit(1)
        }
    }

    return {
        RPC_URL: envVars.RPC_URL,
        PRIVATE_KEY: envVars.PRIVATE_KEY,
        WRAPPER_ADDRESS: envVars.WRAPPER_ADDRESS
            ? ethers.getAddress(envVars.WRAPPER_ADDRESS)
            : null,
        PRICEFEEDL1_ADDRESS: ethers.getAddress(envVars.PRICEFEEDL1_ADDRESS),
        POSITIONS_ADDRESS: ethers.getAddress(envVars.POSITIONS_ADDRESS),
        UNISWAPV3HELPER_ADDRESS: ethers.getAddress(envVars.UNISWAPV3HELPER_ADDRESS),
        MARKET_ADDRESS: ethers.getAddress(envVars.MARKET_ADDRESS),
        LIQUIDITYPOOLFACTORY_ADDRESS: ethers.getAddress(envVars.LIQUIDITYPOOLFACTORY_ADDRESS),
        FEEMANAGER_ADDRESS: ethers.getAddress(envVars.FEEMANAGER_ADDRESS),
    }
}

/**
 * Sets up provider and wallet.
 */
function setupProviderAndWallet(rpcUrl, privateKey) {
    const provider = new ethers.JsonRpcProvider(rpcUrl)
    const wallet = new ethers.Wallet(privateKey, provider)
    return { provider, wallet }
}

/**
 * Returns the Market contract ABI.
 * @returns {object} The Market ABI.
 */
function getMarketAbi() {
    return getAbi("Market")
}

/**
 * Returns the Positions contract ABI.
 * @returns {object} The Positions ABI.
 */
function getPositionsAbi() {
    return getAbi("Positions")
}

/**
 * Returns the PriceFeedL1 contract ABI.
 * @returns {object} The PriceFeedL1 ABI.
 */
function getPriceFeedL1Abi() {
    return getAbi("PriceFeedL1")
}

/**
 * Returns the LiquidityPoolFactory contract ABI.
 * @returns {object} The LiquidityPoolFactory ABI.
 */
function getLiquidityPoolFactoryAbi() {
    return getAbi("LiquidityPoolFactory")
}

/**
 * Returns the LiquidityPool contract ABI.
 * @returns {object} The LiquidityPool ABI.
 */
function getLiquidityPoolAbi() {
    return getAbi("LiquidityPool")
}

/**
 * Returns the UniswapV3Helper contract ABI.
 * @returns {object} The UniswapV3Helper ABI.
 */
function getUniswapV3HelperAbi() {
    return getAbi("UniswapV3Helper")
}

/**
 * Calculates the amount of tokens for a given USD value.
 * @param {string} tokenAddress The address of the token.
 * @param {ethers.Contract} priceFeedL1Contract The PriceFeedL1 contract.
 * @param {string} usdAmount The amount in USD (e.g., "10").
 * @returns {Promise<bigint>} The calculated token amount.
 */
async function calculateTokenAmountFromUsd(tokenContract, priceFeedL1Contract, usdAmount) {
    const decimals = await tokenContract.decimals()
    const tokenAddress = await tokenContract.getAddress()
    const priceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(tokenAddress)
    const targetUsdValue = ethers.parseUnits(usdAmount, 18)
    return (targetUsdValue * BigInt(10n ** decimals)) / priceInUsd
}

/**
 * Fetches and logs details of a position.
 * @param {string|number} posId The position ID.
 * @param {ethers.Contract} marketContract The Market contract instance.
 * @param {ethers.Contract} priceFeedL1Contract The PriceFeedL1 contract instance.
 * @param {ethers.Provider} provider The ethers provider.
 */
async function logPositionDetails(posId, marketContract, priceFeedL1Contract, provider) {
    try {
        const params = await marketContract.getPositionParams(posId)
        // params: baseToken, quoteToken, positionSize, timestamp, isShort, leverage, liquidationFloor, limitPrice, stopLossPrice, currentPnL, collateralLeft

        const [
            baseToken,
            quoteToken,
            positionSize,
            ,
            isShort,
            leverage,
            ,
            ,
            ,
            currentPnL,
            collateralLeft,
        ] = params

        // Fetch symbols and decimals
        const erc20Abi = getErc20Abi()
        const baseTokenContract = new ethers.Contract(baseToken, erc20Abi, provider)
        const quoteTokenContract = new ethers.Contract(quoteToken, erc20Abi, provider)

        const [baseSymbol, baseDecimals, quoteSymbol, quoteDecimals] = await Promise.all([
            baseTokenContract.symbol(),
            baseTokenContract.decimals(),
            quoteTokenContract.symbol(),
            quoteTokenContract.decimals(),
        ])

        // Fetch Position State and openPositions to get initialPrice
        const env = getEnvVars()
        const positionsAbi = getAbi("Positions")
        const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider)

        // Get initialPrice directly from contract storage
        const posParams = await positionsContract.openPositions(posId)
        const initialPrice = posParams.initialPrice

        const stateInt = await positionsContract.getPositionState(posId)
        const states = [
            "NONE",
            "TAKE_PROFIT",
            "ACTIVE",
            "STOP_LOSS",
            "LIQUIDATABLE",
            "BAD_DEBT",
            "EXPIRED",
        ]
        const stateStr = states[Number(stateInt)] || "UNKNOWN"
        const isLiquidable = stateStr === "LIQUIDATABLE" || stateStr === "BAD_DEBT"

        // Calculate USD for the Position Size
        const usdAmountBigInt = await priceFeedL1Contract.getAmountInUsd(baseToken, positionSize)
        const usdAmount = parseFloat(ethers.formatUnits(usdAmountBigInt, 18)).toFixed(2)

        // Calculate PnL in base token and USD
        const pnlInBase = Number(currentPnL)
        const pnlFormatted = ethers.formatUnits(
            pnlInBase < 0 ? -currentPnL : currentPnL,
            baseDecimals
        )
        const pnlUsdBigInt = await priceFeedL1Contract.getAmountInUsd(
            baseToken,
            pnlInBase < 0 ? -currentPnL : currentPnL
        )
        const pnlUsd = parseFloat(ethers.formatUnits(pnlUsdBigInt, 18)).toFixed(2)
        const pnlSign = pnlInBase >= 0 ? "+" : "-"

        // Get current price
        let currentPrice = 0n
        try {
            currentPrice = await priceFeedL1Contract.getPairLatestPrice(baseToken, quoteToken)
        } catch (e) {
            // Price feed might not exist
        }

        // Format prices with quote token decimals (pair price uses quote decimals)
        const currentPriceFormatted = ethers.formatUnits(currentPrice, quoteDecimals)
        const initialPriceFormatted = ethers.formatUnits(initialPrice, quoteDecimals)

        const currentPriceNum = parseFloat(currentPriceFormatted)
        const initialPriceNum = parseFloat(initialPriceFormatted)

        // Calculate profitable price threshold (entry price)
        // For LONG: need price > initialPrice to be profitable
        // For SHORT: need price < initialPrice to be profitable
        const profitableThreshold = initialPriceNum
        const isProfitable = isShort
            ? currentPriceNum < profitableThreshold
            : currentPriceNum > profitableThreshold

        // Verify PnL aligns with price comparison
        // PnL from contract should match our isProfitable calculation
        const pnlAligned = pnlInBase >= 0 === isProfitable

        console.log("\n═══════════════════════════════════════════════════")
        console.log(`  POSITION #${posId} - ${stateStr}${isLiquidable ? " ⚠️" : ""}`)
        console.log("═══════════════════════════════════════════════════")
        console.log(`  Type:       ${isShort ? "SHORT 📉" : "LONG 📈"} ${leverage}x`)
        console.log(`  Pair:       ${baseSymbol}/${quoteSymbol}`)
        console.log(`  Size:       ${ethers.formatUnits(positionSize, baseDecimals)} ${baseSymbol}`)
        console.log(`  Value:      ~$${usdAmount} USD`)
        console.log("───────────────────────────────────────────────────")
        console.log(
            `  PnL:        ${pnlSign}${parseFloat(pnlFormatted).toFixed(
                6
            )} ${baseSymbol} (${pnlSign}$${pnlUsd})`
        )
        console.log(
            `  Collateral: ${ethers.formatUnits(
                collateralLeft < 0 ? -collateralLeft : collateralLeft,
                baseDecimals
            )} ${baseSymbol}`
        )
        console.log("───────────────────────────────────────────────────")
        console.log(`  ${baseSymbol}: ${currentPriceNum.toFixed(0)} ${quoteSymbol}`)
        console.log(
            `  ${isProfitable ? "✅ In Profit" : "⏳ Waiting"} | ${
                isShort ? "BELOW" : "ABOVE"
            } ${profitableThreshold.toFixed(0)} ${quoteSymbol}`
        )
        if (!pnlAligned) {
            console.log(`  ⚠️  PnL may include fees/slippage`)
        }
        console.log("═══════════════════════════════════════════════════\n")
    } catch (error) {
        console.error(`Failed to fetch details for Position ${posId}:`, error.message)
    }
}

/**
 * Generates and logs a pre-flight table and checks capacity.
 * @param {ethers.Provider} provider
 * @param {ethers.Contract} marketContract
 * @param {ethers.Contract} priceFeedL1Contract
 * @param {string} token0Address Collateral token address
 * @param {string} token1Address Target token address
 * @param {bigint} positionAmount
 * @param {number} leverage
 * @param {boolean} isShort
 * @returns {Promise<boolean>} True if capacity left >= borrow amount, false otherwise.
 */
async function checkAndLogPreflightTable(
    provider,
    marketContract,
    priceFeedL1Contract,
    token0Address,
    token1Address,
    positionAmount,
    leverage,
    isShort
) {
    const erc20Abi = getErc20Abi()
    const lpAbi = getLiquidityPoolAbi()

    const token0Contract = new ethers.Contract(token0Address, erc20Abi, provider)
    const token1Contract = new ethers.Contract(token1Address, erc20Abi, provider)

    const [decimals, symbol0, symbol1] = await Promise.all([
        token0Contract.decimals(),
        token0Contract.symbol(),
        token1Contract.symbol(),
    ])

    // Determine which token is base and which is quote (logic similar to PositionLogic.sol)
    const token0UsdPrice = await priceFeedL1Contract.getTokenLatestPriceInUsd(token0Address)
    const isToken0Stable = token0UsdPrice >= 0.9e18 && token0UsdPrice <= 1.1e18

    let baseTokenAddress, quoteTokenAddress, baseSymbol, quoteSymbol
    if (isToken0Stable) {
        quoteTokenAddress = token0Address
        quoteSymbol = symbol0
        baseTokenAddress = token1Address
        baseSymbol = symbol1
    } else {
        baseTokenAddress = token0Address
        baseSymbol = symbol0
        quoteTokenAddress = token1Address
        quoteSymbol = symbol1
    }

    const poolTokenAddress = isShort ? baseTokenAddress : quoteTokenAddress
    const poolSymbol = isShort ? baseSymbol : quoteSymbol

    const poolAddress = await marketContract.getTokenToLiquidityPools(poolTokenAddress)
    if (!poolAddress || poolAddress === ethers.ZeroAddress) {
        console.error(`❌ No liquidity pool found for ${poolSymbol}`)
        return false
    }

    const poolTokenContract = new ethers.Contract(poolTokenAddress, erc20Abi, provider)
    const poolDecimals = await poolTokenContract.decimals()
    const poolBalanceRaw = await poolTokenContract.balanceOf(poolAddress)

    const liquidityPoolContract = new ethers.Contract(poolAddress, lpAbi, provider)
    const capacityLeftRaw = await liquidityPoolContract.borrowCapacityLeft()

    // Uniswap V3 Factory address from Positions.sol or HelperConfig.sol
    const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"
    const v3FactoryAbi = ["function getPool(address,address,uint24) view returns (address)"]
    const v3Factory = new ethers.Contract(UNISWAP_V3_FACTORY, v3FactoryAbi, provider)
    const v3Pool = await v3Factory.getPool(token0Address, token1Address, 3000)

    let expectedBorrowAmountRaw
    if (isShort) {
        // Short: Borrow baseToken
        // For simulation, we simplify: positionAmount is in token0.
        // If token0 is base, it's easy.
        if (!isToken0Stable) {
            expectedBorrowAmountRaw = positionAmount * BigInt(leverage)
        } else {
            const priceRaw = await priceFeedL1Contract.getPairLatestPrice(
                baseTokenAddress,
                quoteTokenAddress
            )
            expectedBorrowAmountRaw =
                (positionAmount * BigInt(10 ** poolDecimals) * BigInt(leverage)) / priceRaw
        }
    } else {
        // Long: Borrow quoteToken
        if (isToken0Stable) {
            // positionAmount is in USDC, we borrow USDC
            expectedBorrowAmountRaw = positionAmount * BigInt(leverage - 1)
        } else {
            // positionAmount is in WBTC, we borrow USDC
            const priceRaw = await priceFeedL1Contract.getPairLatestPrice(
                baseTokenAddress,
                quoteTokenAddress
            )
            expectedBorrowAmountRaw =
                (positionAmount * BigInt(leverage - 1) * priceRaw) / 10n ** BigInt(poolDecimals)
        }
    }

    const willPass = capacityLeftRaw >= expectedBorrowAmountRaw

    console.log("\n====== Pre-flight Check ======")
    console.log(`Operation:       ${isShort ? "Short" : "Long"}`)
    console.log(`Collateral:      ${symbol0}`)
    console.log(`Target:          ${symbol1}`)
    console.log(`V3 Pool:         ${v3Pool}`)
    console.log(
        `Borrow Amount:   ${ethers.formatUnits(
            expectedBorrowAmountRaw,
            poolDecimals
        )} ${poolSymbol}`
    )
    console.log(`Borrow Pool:     ${poolAddress}`)
    console.log(
        `Pool Balance:    ${ethers.formatUnits(poolBalanceRaw, poolDecimals)} ${poolSymbol}`
    )
    console.log(
        `Capacity Left:   ${ethers.formatUnits(capacityLeftRaw, poolDecimals)} ${poolSymbol}`
    )
    console.log(`Would Pass:      ${willPass ? "✅ Yes" : "❌ No"}`)
    console.log("==============================\n")

    return willPass
}

module.exports = {
    getMarketAbi,
    getPositionsAbi,
    getPriceFeedL1Abi,
    getLiquidityPoolFactoryAbi,
    getLiquidityPoolAbi,
    getUniswapV3HelperAbi,
    getErc20Abi,
    getTokenBalance,
    getEnvVars,
    setupProviderAndWallet,
    calculateTokenAmountFromUsd,
    logPositionDetails,
    getSupportedTokens,
    checkAndLogPreflightTable,
}
