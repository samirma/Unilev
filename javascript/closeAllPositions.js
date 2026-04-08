const { ethers } = require("ethers")
const {
    getMarketAbi,
    getPositionsAbi,
    getErc20Abi,
    getPriceFeedL1Abi,
    getEnvVars,
    setupProviderAndWallet,
    getSupportedTokens,
} = require("./utils")

/**
 * Get a snapshot of wallet balances for all supported tokens
 * @param {string} walletAddress
 * @param {Object} supportedTokens - { symbol: address }
 * @param {object} erc20Abi
 * @param {ethers.Provider} provider
 * @returns {Object} - { symbol: { balance: bigint, decimals: number, address: string } }
 */
async function getWalletTokenBalanceSnapshot(walletAddress, supportedTokens, erc20Abi, provider) {
    const snapshot = {}
    for (const [symbol, address] of Object.entries(supportedTokens)) {
        if (symbol === "wrapper") continue
        const contract = new ethers.Contract(address, erc20Abi, provider)
        const [balance, decimals] = await Promise.all([
            contract.balanceOf(walletAddress),
            contract.decimals(),
        ])
        snapshot[symbol] = { balance, decimals, address }
    }
    return snapshot
}

/**
 * Calculate the expected return for a position
 * @param {bigint} posId
 * @param {ethers.Contract} positionsContract
 * @param {ethers.Contract} marketContract
 * @param {ethers.Contract} priceFeedL1Contract
 * @param {ethers.Provider} provider
 * @param {object} erc20Abi
 * @returns {Object} - { tokenSymbol, tokenAddress, expectedAmount, expectedUsd }
 */
async function calculateExpectedReturn(
    posId,
    positionsContract,
    marketContract,
    priceFeedL1Contract,
    provider,
    erc20Abi
) {
    // Get position params from Market contract
    const params = await marketContract.getPositionParams(posId)
    const [, , , , , , , , , currentPnL, collateralLeft] = params

    // Get position details from Positions contract
    const posDetails = await positionsContract.openPositions(posId)
    const initialToken = posDetails.initialToken
    const liquidationReward = posDetails.liquidationReward

    // Get token details
    const tokenContract = new ethers.Contract(initialToken, erc20Abi, provider)
    const [symbol, decimals] = await Promise.all([tokenContract.symbol(), tokenContract.decimals()])

    // Calculate expected return: collateralLeft + liquidationReward
    // collateralLeft already accounts for fees/slippage in the contract
    // liquidationReward is always returned to the trader (see Positions.sol line 641)
    const expectedAmount =
        collateralLeft > 0n ? collateralLeft + liquidationReward : liquidationReward

    // Calculate USD value
    let expectedUsd = 0n
    try {
        expectedUsd = await priceFeedL1Contract.getAmountInUsd(initialToken, expectedAmount)
    } catch (e) {
        // Price feed might not be available
    }

    return {
        tokenSymbol: symbol,
        tokenAddress: initialToken,
        decimals,
        expectedAmount,
        expectedUsd,
        currentPnL,
        collateralLeft,
        liquidationReward,
    }
}

/**
 * Format a token amount with proper decimals
 */
function formatTokenAmount(amount, decimals) {
    return parseFloat(ethers.formatUnits(amount, decimals)).toFixed(6)
}

/**
 * Format a USD amount
 */
function formatUsdAmount(amount) {
    return parseFloat(ethers.formatUnits(amount, 18)).toFixed(2)
}

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars()
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY)

    console.log(`Starting Close All Positions script...`)
    console.log(`Trader: ${wallet.address}`)

    // --- Contract Instances ---
    const marketAbi = getMarketAbi()
    const marketContract = new ethers.Contract(env.MARKET_ADDRESS, marketAbi, wallet)

    const positionsAbi = getPositionsAbi()
    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider)

    const priceFeedL1Abi = getPriceFeedL1Abi()
    const priceFeedL1Contract = new ethers.Contract(
        env.PRICEFEEDL1_ADDRESS,
        priceFeedL1Abi,
        provider
    )

    const erc20Abi = getErc20Abi()
    const supportedTokens = getSupportedTokens()

    if (!supportedTokens) {
        console.error("Failed to load supported tokens")
        process.exit(1)
    }

    try {
        // --- 1. Get Trader Positions ---
        console.log("Fetching open positions...")
        const positionIds = await marketContract.getTraderPositions(wallet.address)

        // Filter out zero IDs just in case, though getTraderPositions should return packed array
        const activeIds = positionIds.filter((id) => id > 0n)

        if (activeIds.length === 0) {
            console.log("No open positions found.")
            return
        }

        console.log(`Found ${activeIds.length} open positions: [${activeIds.join(", ")}]`)

        // Initialize nonce once
        let nonce = await wallet.getNonce()

        // --- 2. Close Each Position ---
        for (const posId of activeIds) {
            console.log(`\n═══════════════════════════════════════════════════`)
            console.log(`  Position #${posId} Closing Summary`)
            console.log(`═══════════════════════════════════════════════════`)

            // Get balance snapshot before closing
            const balanceBefore = await getWalletTokenBalanceSnapshot(
                wallet.address,
                supportedTokens,
                erc20Abi,
                provider
            )

            // Calculate expected return
            let expectedData
            try {
                expectedData = await calculateExpectedReturn(
                    posId,
                    positionsContract,
                    marketContract,
                    priceFeedL1Contract,
                    provider,
                    erc20Abi
                )
                console.log(
                    `  Expected:   ${formatTokenAmount(expectedData.expectedAmount, expectedData.decimals)} ${expectedData.tokenSymbol} (~$${formatUsdAmount(expectedData.expectedUsd)} USD)`
                )
                console.log(
                    `    (Collateral: ${formatTokenAmount(expectedData.collateralLeft > 0n ? expectedData.collateralLeft : 0n, expectedData.decimals)} + Reward: ${formatTokenAmount(expectedData.liquidationReward, expectedData.decimals)})`
                )
            } catch (error) {
                console.error(`  ⚠️  Could not calculate expected return:`, error.message)
                expectedData = null
            }

            // Close the position
            console.log(`  Closing position...`)
            let closeSuccess = false
            try {
                const tx = await marketContract.closePosition(posId, { nonce: nonce++ })
                console.log(`  Transaction: ${tx.hash}`)
                await tx.wait()
                console.log(`  ✅ Position closed successfully`)
                closeSuccess = true
            } catch (error) {
                console.error(`  ❌ Failed to close position:`, error.message || error)
            }

            // Get balance snapshot after closing
            const balanceAfter = await getWalletTokenBalanceSnapshot(
                wallet.address,
                supportedTokens,
                erc20Abi,
                provider
            )

            // Calculate and display actual changes
            if (closeSuccess && expectedData) {
                console.log(`\n  ─────────────────────────────────────────────────`)

                // Find which token changed (should be the initialToken)
                const expectedTokenSymbol = expectedData.tokenSymbol
                const beforeBalance = balanceBefore[expectedTokenSymbol]?.balance || 0n
                const afterBalance = balanceAfter[expectedTokenSymbol]?.balance || 0n
                const actualChange = afterBalance - beforeBalance

                if (actualChange !== 0n) {
                    const actualUsd = await priceFeedL1Contract
                        .getAmountInUsd(expectedData.tokenAddress, actualChange)
                        .catch(() => 0n)

                    console.log(
                        `  Actual:     ${formatTokenAmount(actualChange, expectedData.decimals)} ${expectedData.tokenSymbol} (~$${formatUsdAmount(actualUsd)} USD)`
                    )

                    // Calculate difference
                    const diffAmount = actualChange - expectedData.expectedAmount
                    const diffUsd = actualUsd - expectedData.expectedUsd

                    const diffAmountStr =
                        diffAmount >= 0n
                            ? `+${formatTokenAmount(diffAmount, expectedData.decimals)}`
                            : formatTokenAmount(
                                  diffAmount < 0n ? -diffAmount : diffAmount,
                                  expectedData.decimals
                              )
                    const diffUsdStr =
                        diffUsd >= 0n
                            ? `+$${formatUsdAmount(diffUsd)}`
                            : `-$${formatUsdAmount(diffUsd < 0n ? -diffUsd : diffUsd)}`

                    const sign = diffAmount >= 0n ? "+" : "-"
                    console.log(
                        `  Difference: ${sign}${diffAmountStr} ${expectedData.tokenSymbol} (${diffUsdStr} USD)`
                    )
                } else {
                    console.log(`  Actual:     No balance change detected`)
                }

                // Check for other token changes (in case of different token being returned)
                const otherChanges = []
                for (const [symbol, data] of Object.entries(balanceAfter)) {
                    const before = balanceBefore[symbol]?.balance || 0n
                    const after = data.balance
                    if (after !== before && symbol !== expectedTokenSymbol) {
                        otherChanges.push({
                            symbol,
                            before,
                            after,
                            change: after - before,
                            decimals: data.decimals,
                        })
                    }
                }

                if (otherChanges.length > 0) {
                    console.log(`\n  Other balance changes detected:`)
                    for (const change of otherChanges) {
                        const changeUsd = await priceFeedL1Contract
                            .getAmountInUsd(
                                supportedTokens[change.symbol],
                                change.change > 0n ? change.change : -change.change
                            )
                            .catch(() => 0n)
                        const sign = change.change > 0n ? "+" : "-"
                        console.log(
                            `    ${change.symbol}: ${sign}${formatTokenAmount(change.change > 0n ? change.change : -change.change, change.decimals)} (~$${formatUsdAmount(changeUsd)} USD)`
                        )
                    }
                }
            } else if (!closeSuccess) {
                console.log(`  ⚠️  Position close failed - no balance changes to report`)
            }

            console.log(`═══════════════════════════════════════════════════`)
        }

        console.log("\n✅ All requested operations completed.")
    } catch (error) {
        console.error("\n❌ An error occurred:", error.message || error)
        process.exit(1)
    }
}

main().catch((error) => {
    console.error("An unexpected error occurred:", error)
    process.exit(1)
})
