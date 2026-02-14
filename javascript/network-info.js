const { ethers } = require("ethers")
const path = require("path")
require("dotenv").config({ path: path.resolve(__dirname, "../.env") })

async function main() {
    const rpcUrl = process.env.RPC_URL
    const privateKey = process.env.PRIVATE_KEY
    if (!rpcUrl) {
        console.error("Error: RPC_URL not set in ../.env")
        process.exit(1)
    }

    const provider = new ethers.JsonRpcProvider(rpcUrl)
    const network = await provider.getNetwork()

    console.log(`RPC URL: ${rpcUrl}`)
    console.log(`Network Name: ${network.name}`)
    console.log(`Network ID (chainId): ${network.chainId}`)

    if (privateKey) {
        const wallet = new ethers.Wallet(privateKey, provider)
        console.log(`Wallet Address: ${wallet.address}`)
    }
}

main()
