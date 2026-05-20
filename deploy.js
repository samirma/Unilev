const { execSync } = require('child_process');
require('dotenv').config();

const rpcUrl = process.env.POLYGON_RPC_URL;
const privateKey = process.env.PRIVATE_KEY;

if (!rpcUrl || !privateKey) {
    console.error("❌ Missing POLYGON_RPC_URL or PRIVATE_KEY in .env file");
    process.exit(1);
}

const command = `C:\\Users\\faar_\\.foundry\\bin\\forge script scripts/Deployments.s.sol:Deployments --via-ir --rpc-url ${rpcUrl} --private-key ${privateKey} --broadcast --slow`;

console.log("🚀 Starting deployment to Polygon...");
try {
    execSync(command, { stdio: 'inherit' });
    console.log("✅ Deployment successful!");
} catch (error) {
    console.error("❌ Deployment failed.");
    process.exit(1);
}
