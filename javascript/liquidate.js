const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

/**
 * Loads the contract ABI from the JSON file.
 * @param {string} contractName The name of the contract.
 * @returns {object} The contract ABI.
 */
function getAbi(contractName) {
    try {
        const abiPath = path.resolve(__dirname, `../out/${contractName}.sol/${contractName}.json`);
        const abiFile = fs.readFileSync(abiPath, "utf8");
        return JSON.parse(abiFile).abi;
    } catch (error) {
        console.error(`Error loading contract ABI for ${contractName}:`, error.message);
        process.exit(1);
    }
}

async function main() {
    const { RPC_URL, PRIVATE_KEY, MARKET_ADDRESS } = process.env;

    if (!RPC_URL || !PRIVATE_KEY || !MARKET_ADDRESS) {
        console.error("Error: Ensure RPC_URL, PRIVATE_KEY, and MARKET_ADDRESS are set in ../.env");
        process.exit(1);
    }

    const marketAbi = getAbi("Market");
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    console.log(`Liquidation Bot started. Using wallet: ${wallet.address}`);

    const marketContract = new ethers.Contract(MARKET_ADDRESS, marketAbi, wallet);

    // Check for liquidable positions periodically
    const CHECK_INTERVAL = 10000; // 10 seconds

    const checkAndLiquidate = async () => {
        try {
            console.log("Checking for liquidable positions...");
            const liquidablePositions = await marketContract.getLiquidablePositions();

            // Filter out zero IDs (getPositionState returns NONE for non-existent, but getLiquidablePositions might be padded)
            const posIds = liquidablePositions.filter(id => id > 0n);

            if (posIds.length > 0) {
                console.log(`Found ${posIds.length} liquidable positions: ${posIds.join(", ")}`);

                console.log("Starting liquidation...");
                const tx = await marketContract.liquidatePositions(posIds);
                console.log(`Liquidation transaction sent: ${tx.hash}`);
                await tx.wait();
                console.log("Liquidation successful!");
            } else {
                console.log("No liquidable positions found.");
            }
        } catch (error) {
            console.error("Error during liquidation check:", error.message || error);
        }
    };

    // Run once immediately, then set interval
    await checkAndLiquidate();
    setInterval(checkAndLiquidate, CHECK_INTERVAL);
}

main().catch((error) => {
    console.error("Bot crashed:", error);
    process.exit(1);
});
