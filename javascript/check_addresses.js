const { ethers } = require("ethers");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

async function main() {
    const polygonRpc = process.env.POLYGON_RPC_URL || "https://polygon.drpc.org";
    console.log("Checking bytecode on Polygon mainnet using RPC:", polygonRpc);
    const provider = new ethers.JsonRpcProvider(polygonRpc);

    const addresses = {
        PRICEFEEDL1: process.env.PRICEFEEDL1_ADDRESS,
        POSITIONS: process.env.POSITIONS_ADDRESS,
        MARKET: process.env.MARKET_ADDRESS,
        POOL_FACTORY: process.env.LIQUIDITYPOOLFACTORY_ADDRESS,
        FEEMANAGER: process.env.FEEMANAGER_ADDRESS,
        UNISWAPV3HELPER: process.env.UNISWAPV3HELPER_ADDRESS
    };

    for (const [name, addr] of Object.entries(addresses)) {
        if (!addr) {
            console.log(`${name}: Not configured in .env`);
            continue;
        }
        try {
            const code = await provider.getCode(addr);
            console.log(`${name} (${addr}): ${code === "0x" ? "NO CODE (0x)" : "HAS CODE (" + code.slice(0, 20) + "...)"}`);
        } catch (err) {
            console.error(`Error checking ${name} (${addr}):`, err.message);
        }
    }
}

main().catch(console.error);
