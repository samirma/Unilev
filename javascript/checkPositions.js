const { ethers } = require("ethers");
const { getErc20Abi, getEnvVars, setupProviderAndWallet, logPositionDetails, getMarketAbi, getPositionsAbi, getPriceFeedL1Abi } = require("./utils");

async function main() {
    // --- Environment Setup ---
    const env = getEnvVars();
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

    console.log(`Checking all active positions...`);

    // --- Contract Instances ---
    const marketAbi = getMarketAbi();
    const marketContract = new ethers.Contract(env.MARKET_ADDRESS, marketAbi, provider);

    // Positions contract is ERC721
    const positionsAbi = getPositionsAbi();
    const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);

    const priceFeedL1Abi = getPriceFeedL1Abi();
    const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

    try {
        // --- 1. Get total number of positions (counter) ---
        // 'posId' in Positions.sol tracks the next ID to be minted.
        const nextPosId = await positionsContract.posId();
        console.log(`Scanning up to Position ID: ${nextPosId - 1n}`);

        let activeCount = 0;

        // --- 2. Iterate and Get Details ---
        for (let i = 1n; i < nextPosId; i++) {
            try {
                // Check if position exists (ownerOf reverts if burned/invalid)
                await positionsContract.ownerOf(i);

                // If we are here, position exists
                activeCount++;
                await logPositionDetails(i, marketContract, priceFeedL1Contract, provider);

            } catch (error) {
                // Position likely burned/closed, skip it.
            }
        }

        console.log(`Total Positions: ${activeCount}`);

    } catch (error) {
        console.error("\n❌ An error occurred:", error.message || error);
        process.exit(1);
    }
}

main().catch((error) => {
    console.error("An unexpected error occurred:", error);
    process.exit(1);
});
