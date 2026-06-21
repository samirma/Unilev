const { ethers } = require("ethers");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

async function checkDeployment() {
    const polygonRpc = process.env.POLYGON_RPC_URL || "https://polygon-rpc.com";
    console.log(`Connecting to: ${polygonRpc}`);
    const provider = new ethers.JsonRpcProvider(polygonRpc);

    const addresses = {
        MARKET: process.env.MARKET_ADDRESS,
        POSITIONS: process.env.POSITIONS_ADDRESS,
        LIQUIDITY_POOL_FACTORY: process.env.LIQUIDITYPOOLFACTORY_ADDRESS,
        PRICE_FEED_L1: process.env.PRICEFEEDL1_ADDRESS,
        UNISWAP_V3_HELPER: process.env.UNISWAPV3HELPER_ADDRESS,
        FEE_MANAGER: process.env.FEEMANAGER_ADDRESS,
    };

    console.log("\nChecking deployed bytecode for each address on Polygon:");
    console.log("---------------------------------------------------------");

    for (const [name, addr] of Object.entries(addresses)) {
        if (!addr) {
            console.log(`${name}: Not set in .env`);
            continue;
        }
        try {
            const code = await provider.getCode(addr);
            if (code === "0x") {
                console.log(`❌ ${name} (${addr}): NOT deployed (no bytecode found)`);
            } else {
                console.log(`✅ ${name} (${addr}): DEPLOYED (${(code.length - 2) / 2} bytes)`);
            }
        } catch (e) {
            console.log(`⚠️ ${name} (${addr}): Error checking bytecode - ${e.message}`);
        }
    }
}

checkDeployment().catch(console.error);
