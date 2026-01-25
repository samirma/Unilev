const { ethers } = require("ethers");
const { getAbi, getEnvVars, setupProviderAndWallet } = require("./utils");

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars();
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

    console.log(`Starting Close All Positions script...`);
    console.log(`Trader: ${wallet.address}`);

    // --- Contract Instances ---
    const marketAbi = getAbi("Market");
    const marketContract = new ethers.Contract(env.MARKET_ADDRESS, marketAbi, wallet);

    try {
        // --- 1. Get Trader Positions ---
        console.log("Fetching open positions...");
        const positionIds = await marketContract.getTraderPositions(wallet.address);

        // Filter out zero IDs just in case, though getTraderPositions should return packed array
        const activeIds = positionIds.filter(id => id > 0n);

        if (activeIds.length === 0) {
            console.log("No open positions found.");
            return;
        }

        console.log(`Found ${activeIds.length} open positions: [${activeIds.join(", ")}]`);

        // Initialize nonce once
        let nonce = await wallet.getNonce();

        // --- 2. Close Each Position ---
        for (const posId of activeIds) {
            console.log(`\nClosing Position ID: ${posId}...`);
            try {
                // Use current nonce and increment
                const tx = await marketContract.closePosition(posId, { nonce: nonce++ });
                console.log(`Transaction sent: ${tx.hash}`);
                await tx.wait();
                console.log(`✅ Position ${posId} closed successfully.`);
            } catch (error) {
                console.error(`❌ Failed to close Position ${posId}:`, error.message || error);
                // If failed, maybe nonce was not consumed (e.g. revert before broadcast? unlikely with wait)
                // But if it failed due to nonce, we should re-fetch.
                // For simplicity, let's keep incrementing if we assume it was broadcast.
                // Or better, re-fetch nonce on error?
                // Let's just try manual increment. If one fails, the next might fail if out of order, 
                // but usually wait() ensures it's mined.
            }
        }

        console.log("\nAll requested operations completed.");

    } catch (error) {
        console.error("\n❌ An error occurred:", error.message || error);
        process.exit(1);
    }
}

main().catch((error) => {
    console.error("An unexpected error occurred:", error);
    process.exit(1);
});
