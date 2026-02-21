const { ethers } = require("ethers");
const { getErc20Abi, getEnvVars, setupProviderAndWallet, calculateTokenAmountFromUsd, logPositionDetails, getMarketAbi, getPriceFeedL1Abi, getSupportedTokens } = require("./utils");

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars();
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

    console.log(`Open Long Position Script started. Using wallet: ${wallet.address}`);

    // --- Contract Instances ---
    const erc20Abi = getErc20Abi();
    const marketAbi = getMarketAbi();
    const priceFeedL1Abi = getPriceFeedL1Abi();

    const supportedTokens = getSupportedTokens();

    // We are using USDC as collateral to long WBTC
    // token0 = USDC (Collateral)
    // token1 = WBTC (Long Target)
    const token0Address = supportedTokens.USDC; // Collateral
    const token1Address = supportedTokens.WBTC; // Target

    const token0Contract = new ethers.Contract(token0Address, erc20Abi, wallet);
    const marketContract = new ethers.Contract(env.MARKET_ADDRESS, marketAbi, wallet);
    const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

    try {
        // --- 1. Calculate Amount of USDC for 1.1 units ---
        console.log("Using 1.1 USDC as collateral (since 1 USDC is currently < $1.00 minimum)...");
        const decimals = await token0Contract.decimals();
        // Since 1 USDC is slightly under 1 USD ($0.999), the contract reverts with Positions__AMOUNT_TO_SMALL.
        // Bypassing by using 1.1 USDC.
        const positionAmount = ethers.parseUnits("1.1", decimals);

        console.log(`Amount: ${ethers.formatUnits(positionAmount, decimals)} USDC`);

        const balance = await token0Contract.balanceOf(wallet.address);
        console.log(`Wallet USDC Balance: ${ethers.formatUnits(balance, decimals)}`);

        if (balance < positionAmount) {
            console.error("❌ Insufficient USDC Balance!");
            process.exit(1);
        }

        // --- 2. Approve Positions Contract ---
        console.log("Approving Positions contract...");
        // Note: Market.sol calls SafeERC20.forceApprove, but we must approve POSITIONS directly as it pulls funds from msg.sender (Trader)
        const txApprove = await token0Contract.approve(env.POSITIONS_ADDRESS, positionAmount);
        await txApprove.wait();
        console.log("- Approved Positions.");

        // --- 3. Open Long Position ---
        console.log("Opening Long Position...");

        // Params:
        // address _token0 (Collateral - USDC)
        // address _token1 (Target - WBTC)
        // uint24 _fee (3000 -> 0.3%)
        // bool _isShort (false)
        // uint8 _leverage (2)
        // uint128 _amount (positionAmount)
        // uint160 _limitPrice (0)
        // uint256 _stopLossPrice (0)

        const fee = 3000;
        const isShort = false;
        const leverage = 2;
        const limitPrice = 0;
        const stopLossPrice = 0;

        try {
            console.log("Simulating transaction...");
            await marketContract.openPosition.staticCall(
                token0Address, token1Address, fee, isShort, leverage, positionAmount, limitPrice, stopLossPrice,
                { from: wallet.address }
            );
        } catch (simError) {
            console.error("Simulation failed:", simError);
            process.exit(1);
        }

        const txOpen = await marketContract.openPosition(
            token0Address,
            token1Address,
            fee,
            isShort,
            leverage,
            positionAmount,
            limitPrice,
            stopLossPrice,
            { gasLimit: 5000000, nonce: txApprove.nonce + 1 }
        );

        console.log(`Transaction sent: ${txOpen.hash}`);
        const receipt = await txOpen.wait();
        console.log("Position opened successfully!");

        // --- 4. Parse Event Logs ---
        for (const log of receipt.logs) {
            try {
                const parsedLog = marketContract.interface.parseLog(log);
                if (parsedLog && parsedLog.name === "PositionOpened") {
                    await logPositionDetails(parsedLog.args.posId, marketContract, priceFeedL1Contract, provider);
                }
            } catch (e) {
                // Ignore logs that don't belong to the Market contract
            }
        }

    } catch (error) {
        console.error("\n❌ An error occurred:", error.message || error);
        if (error.data) {
            console.error("Error Data:", error.data);
        }
        process.exit(1);
    }
}

main().catch((error) => {
    console.error("An unexpected error occurred:", error);
    process.exit(1);
});
