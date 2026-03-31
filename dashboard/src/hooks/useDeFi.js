import { useState, useCallback, useEffect } from "react"
import { ethers } from "ethers"
import { useAccount, useWalletClient } from "wagmi"

// Import ABIs
import ERC20ABI from "../abis/ERC20.json"
import MarketABI from "../abis/Market.json"
import PositionsABI from "../abis/Positions.json"
import PriceFeedL1ABI from "../abis/PriceFeedL1.json"
import LiquidityPoolFactoryABI from "../abis/LiquidityPoolFactory.json"
import LiquidityPoolABI from "../abis/LiquidityPool.json"
import FeeManagerABI from "../abis/FeeManager.json"
import supportedTokens from "../config/supported_tokens.json"

// Create a static array of supported tokens (excluding 'wrapper' and duplicates, though in a UI, it's simpler to just filter 'wrapper')
export const SUPPORTED_TOKENS_LIST = Object.entries(supportedTokens)
    .filter(([key]) => key !== "wrapper")
    .map(([key, address]) => ({ key, name: key, address }))

// Constants
const ADDRESSES = {
    ...supportedTokens,
    PRICEFEEDL1: process.env.PRICEFEEDL1_ADDRESS,
    POSITIONS: process.env.POSITIONS_ADDRESS,
    MARKET: process.env.MARKET_ADDRESS,
    POOL_FACTORY: process.env.LIQUIDITYPOOLFACTORY_ADDRESS,
    FEEMANAGER_ADDRESS: process.env.FEEMANAGER_ADDRESS,
}

export function useDeFi() {
    const { address, isConnected } = useAccount()
    const { data: walletClient } = useWalletClient()

    // Providers
    const [readProvider, setReadProvider] = useState(null)
    const [isMetaMaskInstalled, setIsMetaMaskInstalled] = useState(false)

    useEffect(() => {
        const initProvider = async () => {
            const hasMetaMask = typeof window !== "undefined" && !!window.ethereum
            setIsMetaMaskInstalled(hasMetaMask)

            // Priority: Local RPC_URL if configured
            if (process.env.RPC_URL) {
                const provider = new ethers.JsonRpcProvider(process.env.RPC_URL)
                setReadProvider(provider)
            }
            // Fallback: window.ethereum (MetaMask)
            else if (hasMetaMask) {
                const provider = new ethers.BrowserProvider(window.ethereum)
                setReadProvider(provider)
            }
            // Ultimate Fallback: Polygon Public RPC
            else {
                const provider = new ethers.JsonRpcProvider("https://polygon-rpc.com")
                setReadProvider(provider)
            }
        }
        initProvider()
    }, [])

    const getSigner = useCallback(async () => {
        if (!walletClient || typeof window === "undefined" || !window.ethereum) return null
        const provider = new ethers.BrowserProvider(window.ethereum)
        return await provider.getSigner()
    }, [walletClient])

    // --- Logic from utils.js adapted for React ---

    const getTokenBalance = useCallback(
        async (tokenAddress, userAddress) => {
            if (!readProvider || !tokenAddress || !userAddress) return null
            try {
                const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider)
                const priceFeed = new ethers.Contract(
                    ADDRESSES.PRICEFEEDL1,
                    PriceFeedL1ABI.abi,
                    readProvider
                )

                const [symbol, decimals, balance] = await Promise.all([
                    contract.symbol(),
                    contract.decimals(),
                    contract.balanceOf(userAddress),
                ])

                const formattedBalance = ethers.formatUnits(balance, decimals)

                // Calculate USD Value
                const usdValueBigInt = await priceFeed.getAmountInUsd(tokenAddress, balance)
                const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2)

                return {
                    symbol,
                    decimals,
                    balance: formattedBalance,
                    usdValue,
                    rawBalance: balance,
                }
            } catch (error) {
                console.error("Error fetching token balance:", error)
                return null
            }
        },
        [readProvider]
    )

    const getNativeBalance = useCallback(
        async (userAddress) => {
            if (!readProvider || !userAddress) return null
            try {
                const balance = await readProvider.getBalance(userAddress)

                // On Polygon, the native token is POL (formerly MATIC)
                // MATIC/USD Price Feed on Polygon Mainnet: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
                const maticUsdAggregator = new ethers.Contract(
                    "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
                    [
                        "function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
                        "function decimals() external view returns (uint8)",
                    ],
                    readProvider
                )

                const [roundData, decimals] = await Promise.all([
                    maticUsdAggregator.latestRoundData(),
                    maticUsdAggregator.decimals(),
                ])

                const price = Number(roundData.answer) / 10 ** Number(decimals)
                const formattedBalance = parseFloat(ethers.formatEther(balance))
                const usdValue = (formattedBalance * price).toFixed(2)

                return {
                    symbol: "POL",
                    decimals: 18,
                    balance: formattedBalance.toString(),
                    usdValue,
                    rawBalance: balance,
                }
            } catch (error) {
                console.error("Error fetching native balance:", error)
                return null
            }
        },
        [readProvider]
    )

    const calculateTokenAmountFromUsd = useCallback(
        async (tokenAddress, usdAmount) => {
            if (!readProvider) return 0n
            try {
                const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider)
                const priceFeed = new ethers.Contract(
                    ADDRESSES.PRICEFEEDL1,
                    PriceFeedL1ABI.abi,
                    readProvider
                )

                const decimals = await contract.decimals()
                const priceInUsd = await priceFeed.getTokenLatestPriceInUsd(tokenAddress)

                const targetUsdValue = ethers.parseUnits(usdAmount.toString(), 18)
                // Formula: (TargetUSD * 10^Decimals) / PriceUSD
                return (targetUsdValue * 10n ** BigInt(decimals)) / priceInUsd
            } catch (error) {
                console.error("Error calculating token amount:", error)
                return 0n
            }
        },
        [readProvider]
    )

    const getAmountInUsd = useCallback(
        async (tokenAddress, amount) => {
            if (!readProvider) return 0n
            try {
                const priceFeed = new ethers.Contract(
                    ADDRESSES.PRICEFEEDL1,
                    PriceFeedL1ABI.abi,
                    readProvider
                )
                return await priceFeed.getAmountInUsd(tokenAddress, amount)
            } catch (error) {
                console.error("Error calculating USD amount:", error)
                return 0n
            }
        },
        [readProvider]
    )

    const getAllowance = useCallback(
        async (tokenAddress, owner, spender) => {
            if (!readProvider || !tokenAddress || !owner || !spender) return 0n
            try {
                const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider)
                return await contract.allowance(owner, spender)
            } catch (error) {
                console.error("Error fetching allowance:", error)
                return 0n
            }
        },
        [readProvider]
    )

    const approveToken = useCallback(
        async (tokenAddress, spender, amount = ethers.MaxUint256) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")
            const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, signer)
            return await contract.approve(spender, amount)
        },
        [getSigner]
    )

    const simulateOpenPosition = useCallback(
        async (token0, token1, isShort, amount, leverage) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            // Validate leverage before simulation
            if (leverage < 2) {
                return {
                    success: false,
                    error: {
                        message: "Positions__LEVERAGE_NOT_IN_RANGE",
                        reason: "Leverage must be at least 2x",
                    },
                }
            }

            const marketContract = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, signer)

            try {
                if (isShort) {
                    await marketContract.openShortPosition.staticCall(
                        token0,
                        token1,
                        3000, // fee
                        leverage,
                        amount,
                        0, // limitPrice
                        0, // stopLossPrice
                        { gasLimit: 5000000 }
                    )
                } else {
                    await marketContract.openLongPosition.staticCall(
                        token0,
                        token1,
                        3000, // fee
                        leverage,
                        amount,
                        0, // limitPrice
                        0, // stopLossPrice
                        { gasLimit: 5000000 }
                    )
                }
                return { success: true }
            } catch (error) {
                return { success: false, error }
            }
        },
        [getSigner]
    )

    const openPosition = useCallback(
        async (token0, token1, isShort, amount, leverage) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            // Validate leverage before sending transaction
            if (leverage < 2) {
                throw new Error("Leverage must be at least 2x (contract requires leverage > 1)")
            }

            // Re-create instances with the correct signer
            const marketContract = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, signer)

            // First simulate to catch any revert errors before sending
            let simulationSuccess = false
            try {
                if (isShort) {
                    await marketContract.openShortPosition.staticCall(
                        token0,
                        token1,
                        3000, // fee
                        leverage,
                        amount,
                        0, // limitPrice
                        0, // stopLossPrice
                        { gasLimit: 5000000 }
                    )
                } else {
                    await marketContract.openLongPosition.staticCall(
                        token0,
                        token1,
                        3000, // fee
                        leverage,
                        amount,
                        0, // limitPrice
                        0, // stopLossPrice
                        { gasLimit: 5000000 }
                    )
                }
                simulationSuccess = true
            } catch (simError) {
                console.error("Simulation failed:", simError)
                // Re-throw the simulation error so the UI can handle it
                throw simError
            }

            // Only proceed if simulation passed
            if (!simulationSuccess) {
                throw new Error("Transaction simulation failed")
            }

            // Open Position
            let tx
            if (isShort) {
                tx = await marketContract.openShortPosition(
                    token0,
                    token1,
                    3000, // fee
                    leverage,
                    amount,
                    0, // limitPrice
                    0, // stopLossPrice
                    { gasLimit: 5000000 }
                )
            } else {
                tx = await marketContract.openLongPosition(
                    token0,
                    token1,
                    3000, // fee
                    leverage,
                    amount,
                    0, // limitPrice
                    0, // stopLossPrice
                    { gasLimit: 5000000 }
                )
            }
            return tx
        },
        [getSigner]
    )

    const closePosition = useCallback(
        async (posId) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            const marketContract = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, signer)
            const tx = await marketContract.closePosition(posId, { gasLimit: 2000000 })
            return tx
        },
        [getSigner]
    )

    const getPositionDetails = useCallback(
        async (posId) => {
            if (!readProvider || !ADDRESSES.POSITIONS || ADDRESSES.POSITIONS === ethers.ZeroAddress)
                return null
            try {
                // Verify code exists at address to avoid BAD_DATA errors on wrong networks
                const code = await readProvider.getCode(ADDRESSES.POSITIONS)
                if (code === "0x") return null

                const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)
                const priceFeed = new ethers.Contract(
                    ADDRESSES.PRICEFEEDL1,
                    PriceFeedL1ABI.abi,
                    readProvider
                )
                const positions = new ethers.Contract(
                    ADDRESSES.POSITIONS,
                    PositionsABI.abi,
                    readProvider
                )

                // Check ownership/existence
                // positions.ownerOf might revert if burned
                let owner
                try {
                    owner = await positions.ownerOf(posId)
                } catch {
                    return null // Position closed/burned
                }

                const params = await market.getPositionParams(posId)
                // params: baseToken, quoteToken, positionSize, timestamp, isShort, leverage...

                const [baseToken, quoteToken, positionSize, , isShort, leverage] = params

                const baseContract = new ethers.Contract(baseToken, ERC20ABI.abi, readProvider)
                const quoteContract = new ethers.Contract(quoteToken, ERC20ABI.abi, readProvider)

                const [baseSymbol, baseDecimals, quoteSymbol] = await Promise.all([
                    baseContract.symbol(),
                    baseContract.decimals(),
                    quoteContract.symbol(),
                ])

                const usdValueBigInt = await priceFeed.getAmountInUsd(baseToken, positionSize)
                const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2)

                const stateInt = await positions.getPositionState(posId)
                const states = [
                    "NONE",
                    "TAKE_PROFIT",
                    "ACTIVE",
                    "STOP_LOSS",
                    "LIQUIDATABLE",
                    "BAD_DEBT",
                    "EXPIRED",
                ]
                const state = states[Number(stateInt)] || "UNKNOWN"

                return {
                    id: posId.toString(),
                    owner,
                    state,
                    isShort,
                    leverage: leverage.toString(),
                    baseToken,
                    quoteToken,
                    baseSymbol,
                    quoteSymbol,
                    size: ethers.formatUnits(positionSize, baseDecimals),
                    sizeUsd: usdValue,
                }
            } catch (error) {
                console.error(`Error fetching pos ${posId}:`, error)
                return null
            }
        },
        [readProvider]
    )

    /**
     * Calculate position opening parameters using Market contract
     * @param {string} price - Current price from oracle
     * @param {number} leverage - Leverage multiplier (2-5)
     * @param {bigint} baseCollateralAmount - Collateral amount after fees (in base token decimals)
     * @param {boolean} isShort - True for short position
     * @param {string} baseToken - Base token address
     * @param {string} quoteToken - Quote token address
     * @returns {Promise<{breakEvenLimit: string, totalBorrow: string, borrowToken: string, liquidityPoolToken: string}|null>}
     */
    const calculatePositionOpening = useCallback(
        async (price, leverage, baseCollateralAmount, isShort, baseToken, quoteToken) => {
            if (!readProvider || !ADDRESSES.MARKET || ADDRESSES.MARKET === ethers.ZeroAddress)
                return null
            try {
                // Verify code exists at address
                const code = await readProvider.getCode(ADDRESSES.MARKET)
                if (code === "0x") return null

                const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)

                // Call the calculatePositionOpening method
                const result = await market.calculatePositionOpening(
                    price,
                    leverage,
                    baseCollateralAmount,
                    isShort,
                    baseToken,
                    quoteToken
                )

                // Destructure the result tuple
                const [breakEvenLimit, totalBorrow, borrowToken, liquidityPoolToken] = result

                return {
                    breakEvenLimit: breakEvenLimit.toString(),
                    totalBorrow: totalBorrow.toString(),
                    borrowToken,
                    liquidityPoolToken,
                }
            } catch (error) {
                console.error("Error calculating position opening:", error)
                return null
            }
        },
        [readProvider]
    )

    const getPositionsCount = useCallback(async () => {
        if (!readProvider || !ADDRESSES.POSITIONS || ADDRESSES.POSITIONS === ethers.ZeroAddress)
            return 0n
        try {
            // Verify code exists at address to avoid BAD_DATA errors on wrong networks
            const code = await readProvider.getCode(ADDRESSES.POSITIONS)
            if (code === "0x") {
                console.warn("Positions contract not found on this network")
                return 0n
            }

            const positions = new ethers.Contract(
                ADDRESSES.POSITIONS,
                PositionsABI.abi,
                readProvider
            )
            return await positions.posId()
        } catch (error) {
            console.error("Error fetching positions count:", error)
            return 0n
        }
    }, [readProvider])

    const getPoolBorrowCapacity = useCallback(
        async (tokenAddress) => {
            if (!readProvider || !tokenAddress) return null
            try {
                const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)
                const poolAddress = await market.getTokenToLiquidityPools(tokenAddress)
                if (!poolAddress || poolAddress === ethers.ZeroAddress) return null

                const poolContract = new ethers.Contract(
                    poolAddress,
                    LiquidityPoolABI.abi,
                    readProvider
                )
                const capacityBigInt = await poolContract.borrowCapacityLeft()

                const tokenContract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider)
                const decimals = await tokenContract.decimals()

                return {
                    rawCapacity: capacityBigInt,
                    capacityFormatted: ethers.formatUnits(capacityBigInt, decimals),
                    decimals: decimals,
                }
            } catch (error) {
                console.error("Error fetching borrow capacity:", error)
                return null
            }
        },
        [readProvider]
    )

    // Calculate required borrow amount using the Market contract's calculatePositionOpening method
    const calculateRequiredBorrow = useCallback(
        async (marginTokenAddress, tradingTokenAddress, isShort, marginAmount, leverage) => {
            if (
                !readProvider ||
                !marginTokenAddress ||
                !tradingTokenAddress ||
                !marginAmount ||
                leverage < 2
            ) {
                return null
            }
            try {
                const priceFeed = new ethers.Contract(
                    ADDRESSES.PRICEFEEDL1,
                    PriceFeedL1ABI.abi,
                    readProvider
                )
                const feeManager = new ethers.Contract(
                    ADDRESSES.FEEMANAGER_ADDRESS,
                    FeeManagerABI.abi,
                    readProvider
                )

                // Get token decimals
                const marginContract = new ethers.Contract(
                    marginTokenAddress,
                    ERC20ABI.abi,
                    readProvider
                )
                const tradingContract = new ethers.Contract(
                    tradingTokenAddress,
                    ERC20ABI.abi,
                    readProvider
                )
                const [marginDecimals, tradingDecimals] = await Promise.all([
                    marginContract.decimals(),
                    tradingContract.decimals(),
                ])

                // Determine base and quote tokens based on price stability
                const marginPriceUsd = await priceFeed.getTokenLatestPriceInUsd(marginTokenAddress)
                const isMarginStable =
                    marginPriceUsd >= 9n * 10n ** 17n && marginPriceUsd <= 11n * 10n ** 17n

                const baseToken = isMarginStable ? tradingTokenAddress : marginTokenAddress
                const quoteToken = isMarginStable ? marginTokenAddress : tradingTokenAddress
                const baseDecimals = isMarginStable ? tradingDecimals : marginDecimals
                const quoteDecimals = isMarginStable ? marginDecimals : tradingDecimals
                const baseDecimalsPow = 10n ** BigInt(baseDecimals)
                const quoteDecimalsPow = 10n ** BigInt(quoteDecimals)

                // Get the pair price (base/quote)
                const price = await priceFeed.getPairLatestPrice(baseToken, quoteToken)

                // Estimate baseCollateralAmount by applying fees and potential swap
                // This mirrors the logic in Positions._openPosition
                const collateralToken = isShort ? quoteToken : baseToken
                let baseCollateralAmount = marginAmount

                // Deduct fees if user is connected
                if (address) {
                    const [treasureFee, liquidationRewardRate] = await feeManager.getFees(address)
                    const liquidationReward =
                        (marginAmount * BigInt(liquidationRewardRate)) / 10000n
                    baseCollateralAmount = baseCollateralAmount - liquidationReward
                    const treasureAmount = (baseCollateralAmount * BigInt(treasureFee)) / 10000n
                    baseCollateralAmount = baseCollateralAmount - treasureAmount
                }

                // If margin token is not the collateral token, estimate swap output
                if (marginTokenAddress.toLowerCase() !== collateralToken.toLowerCase()) {
                    const priceToCollateral = await priceFeed.getPairLatestPrice(
                        marginTokenAddress,
                        collateralToken
                    )
                    const divisor = isShort ? baseDecimalsPow : quoteDecimalsPow
                    const estimatedOut = (baseCollateralAmount * priceToCollateral) / divisor
                    baseCollateralAmount = estimatedOut
                }

                // Call Market contract's calculatePositionOpening method with the estimated collateral
                const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)

                const result = await market.calculatePositionOpening(
                    price,
                    leverage,
                    baseCollateralAmount,
                    isShort,
                    baseToken,
                    quoteToken
                )

                const [breakEvenLimit, totalBorrow, borrowToken, liquidityPoolToken] = result

                // Get decimals for borrow token
                const isBorrowBase = borrowToken.toLowerCase() === baseToken.toLowerCase()
                const borrowTokenDecimals = isBorrowBase ? baseDecimals : marginDecimals

                // Calculate USD value of the borrow
                const borrowUsdValue = await priceFeed.getAmountInUsd(borrowToken, totalBorrow)

                return {
                    totalBorrow,
                    borrowTokenAddress: borrowToken,
                    borrowTokenDecimals,
                    totalBorrowFormatted: ethers.formatUnits(totalBorrow, borrowTokenDecimals),
                    borrowUsdValue,
                    borrowUsdFormatted: parseFloat(ethers.formatUnits(borrowUsdValue, 18)).toFixed(
                        2
                    ),
                    breakEvenPrice: breakEvenLimit,
                    price,
                    isBaseMargin: !isMarginStable,
                }
            } catch (error) {
                console.error("Error calculating required borrow:", error)
                return null
            }
        },
        [readProvider, address]
    )

    // --- Pool & Protocol Logic ---

    const getProtocolBalances = useCallback(async () => {
        if (!readProvider) return null
        try {
            const priceFeed = new ethers.Contract(
                ADDRESSES.PRICEFEEDL1,
                PriceFeedL1ABI.abi,
                readProvider
            )
            const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)

            const positionsBalances = {}
            const poolBalances = {}

            for (const token of SUPPORTED_TOKENS_LIST) {
                if (!token.address) continue
                const tokenContract = new ethers.Contract(token.address, ERC20ABI.abi, readProvider)

                // 1. POSITIONS Contract Balance
                const posBal = await tokenContract.balanceOf(ADDRESSES.POSITIONS)
                const posDecimals = await tokenContract.decimals()
                const posUsdBig = await priceFeed.getAmountInUsd(token.address, posBal)

                positionsBalances[token.key] = {
                    balance: ethers.formatUnits(posBal, posDecimals),
                    usdValue: parseFloat(ethers.formatUnits(posUsdBig, 18)).toFixed(2),
                }

                // 2. Liquidity Pool Info
                const poolAddress = await market.getTokenToLiquidityPools(token.address)
                if (poolAddress && poolAddress !== ethers.ZeroAddress) {
                    const poolContract = new ethers.Contract(
                        poolAddress,
                        LiquidityPoolABI.abi,
                        readProvider
                    )
                    const totalAssets = await poolContract.totalAssets()
                    const totalAssetsUsdBig = await priceFeed.getAmountInUsd(
                        token.address,
                        totalAssets
                    )

                    // User Shares (if connected)
                    let userShares = 0n
                    let userAssets = 0n
                    if (address) {
                        userShares = await poolContract.balanceOf(address)
                        if (userShares > 0n) {
                            userAssets = await poolContract.convertToAssets(userShares)
                        }
                    }

                    poolBalances[token.key] = {
                        address: poolAddress,
                        totalAssets: ethers.formatUnits(totalAssets, posDecimals),
                        totalAssetsUsd: parseFloat(
                            ethers.formatUnits(totalAssetsUsdBig, 18)
                        ).toFixed(2),
                        userShares: ethers.formatUnits(userShares, posDecimals),
                        userAssets: ethers.formatUnits(userAssets, posDecimals),
                    }
                }
            }

            return { positionsBalances, poolBalances }
        } catch (error) {
            console.error("Error fetching protocol balances:", error)
            return null
        }
    }, [readProvider, address])

    const depositToPool = useCallback(
        async (tokenKey, amount) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            const tokenAddress = ADDRESSES[tokenKey]
            if (!tokenAddress) throw new Error("Invalid Token")

            // Get Pool Address
            const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)
            const poolAddress = await market.getTokenToLiquidityPools(tokenAddress)

            if (!poolAddress || poolAddress === ethers.ZeroAddress)
                throw new Error("Pool not found")

            const tokenContract = new ethers.Contract(tokenAddress, ERC20ABI.abi, signer)
            const poolContract = new ethers.Contract(poolAddress, LiquidityPoolABI.abi, signer)

            // Approve
            const allowance = await tokenContract.allowance(address, poolAddress)
            if (allowance < amount) {
                const txApprove = await tokenContract.approve(poolAddress, ethers.MaxUint256)
                await txApprove.wait()
            }

            // Deposit
            const tx = await poolContract.deposit(amount, address)
            return tx
        },
        [address, getSigner, readProvider]
    )

    const redeemFromPool = useCallback(
        async (tokenKey, shares) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            const tokenAddress = ADDRESSES[tokenKey]
            const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider)
            const poolAddress = await market.getTokenToLiquidityPools(tokenAddress)

            const poolContract = new ethers.Contract(poolAddress, LiquidityPoolABI.abi, signer)

            // redeem(shares, receiver, owner)
            const tx = await poolContract.redeem(shares, address, address)
            return tx
        },
        [address, getSigner, readProvider]
    )

    // --- Fee Manager Logic ---

    const getFeeDefaults = useCallback(async () => {
        if (!readProvider) return null
        try {
            const feeManager = new ethers.Contract(
                ADDRESSES.FEEMANAGER_ADDRESS,
                FeeManagerABI.abi,
                readProvider
            )
            const [treasureFee, liquidationReward] = await Promise.all([
                feeManager.defaultTreasureFee(),
                feeManager.defaultLiquidationReward(),
            ])
            return {
                treasureFee: treasureFee.toString(),
                liquidationReward: liquidationReward.toString(),
            }
        } catch (error) {
            console.error("Error fetching fee defaults:", error)
            return null
        }
    }, [readProvider])

    const updateFeeDefaults = useCallback(
        async (treasureFee, liquidationReward) => {
            const signer = await getSigner()
            if (!signer) throw new Error("Wallet not connected")

            const feeManager = new ethers.Contract(
                ADDRESSES.FEEMANAGER_ADDRESS,
                FeeManagerABI.abi,
                signer
            )
            const tx = await feeManager.setDefaultFees(treasureFee, liquidationReward)
            return tx
        },
        [getSigner]
    )

    return {
        ADDRESSES,
        readProvider,
        getTokenBalance,
        getAmountInUsd,
        calculateTokenAmountFromUsd,
        calculateRequiredBorrow,
        calculatePositionOpening,
        openPosition,
        simulateOpenPosition,
        closePosition,
        getPositionDetails,
        getPositionsCount,
        getPoolBorrowCapacity,
        getProtocolBalances,
        depositToPool,
        redeemFromPool,
        getFeeDefaults,
        updateFeeDefaults,
        getNativeBalance,
        getAllowance,
        approveToken,
        SUPPORTED_TOKENS_LIST,
        isMetaMaskInstalled,
    }
}
