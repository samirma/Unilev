const fs = require("fs")
const path = require("path")
const { ethers } = require("ethers")
const { getChainId } = require("./network-info")

function getErc20Abi() {
    return [
        "function name() view returns (string)",
        "function symbol() view returns (string)",
        "function decimals() view returns (uint8)",
        "function balanceOf(address) view returns (uint256)",
    ]
}

async function getTokenSymbol(provider, tokenAddress) {
    const contract = new ethers.Contract(tokenAddress, getErc20Abi(), provider)
    try {
        return await contract.symbol()
    } catch (error) {
        console.error(`Error getting symbol for ${tokenAddress}:`, error.message)
        return null
    }
}

async function updateEnv() {
    const chainId = await getChainId()
    const runLatestPath = path.join(
        __dirname,
        `../broadcast/Deployments.s.sol/${chainId}/run-latest.json`
    )
    const envPath = path.join(__dirname, "../.env")
    const supportedTokensPath = path.join(__dirname, "../supported_tokens.json")

    const rpcUrl = process.env.RPC_URL
    if (!rpcUrl) {
        console.error("Error: RPC_URL not set in .env")
        return
    }
    const provider = new ethers.JsonRpcProvider(rpcUrl)

    let data
    try {
        data = fs.readFileSync(runLatestPath, "utf8")
    } catch (err) {
        console.error("Error reading run-latest.json:", err)
        return
    }

    const runLatest = JSON.parse(data)
    const createTransactions = runLatest.transactions.filter(
        (tx) => tx.transactionType === "CREATE"
    )

    if (createTransactions.length === 0) {
        console.log('No "CREATE" transactions found in run-latest.json')
        return
    }

    let envLines = []
    try {
        const envData = fs.readFileSync(envPath, "utf8")
        envLines = envData.split("\n")
    } catch (err) {
        // .env doesn't exist yet
    }

    const envMap = new Map()
    envLines.forEach((line, index) => {
        const key = line.split("=")[0]
        if (key) {
            envMap.set(key, { line, index })
        }
    })

    createTransactions.forEach((tx) => {
        const { contractName, contractAddress } = tx
        if (contractName && contractAddress) {
            const key = contractName.toUpperCase() + "_ADDRESS"
            const newLine = `${key}=${contractAddress}`
            if (envMap.has(key)) {
                const { index } = envMap.get(key)
                envLines[index] = newLine
            } else {
                envLines.push(newLine)
            }
        }
    })

    let wrapperAddress = null

    if (runLatest.returns && runLatest.returns.wrapperAddress) {
        wrapperAddress = runLatest.returns.wrapperAddress.value
        const key = "WRAPPER_ADDRESS"
        const newLine = `${key}=${wrapperAddress}`
        if (envMap.has(key)) {
            const { index } = envMap.get(key)
            envLines[index] = newLine
        } else {
            envLines.push(newLine)
        }
    }

    const initializeTokensTx = runLatest.transactions.find(
        (tx) => tx.function === "initializeTokens(address[],address[])"
    )

    const supportedTokens = {}

    if (initializeTokensTx && initializeTokensTx.arguments && initializeTokensTx.arguments[0]) {
        const rawAddresses = initializeTokensTx.arguments[0]
        const tokenAddresses = rawAddresses
            .replace(/^\[|\]$/g, "")
            .split(",")
            .map((addr) => addr.trim())

        console.log("Fetching token symbols...")

        for (const tokenAddress of tokenAddresses) {
            const symbol = await getTokenSymbol(provider, tokenAddress)
            if (symbol) {
                supportedTokens[symbol] = tokenAddress
                console.log(`  ${symbol}: ${tokenAddress}`)
            }
        }
    }

    if (wrapperAddress) {
        const wrapperSymbol = await getTokenSymbol(provider, wrapperAddress)
        if (wrapperSymbol) {
            supportedTokens["wrapper"] = { symbol: wrapperSymbol, address: wrapperAddress }
            console.log(`  wrapper (${wrapperSymbol}): ${wrapperAddress}`)
        }
    }

    try {
        fs.writeFileSync(envPath, envLines.join("\n"), "utf8")
        console.log("Successfully updated .env file with contract addresses.")
    } catch (err) {
        console.error("Error writing to .env file:", err)
        return
    }

    try {
        fs.writeFileSync(supportedTokensPath, JSON.stringify(supportedTokens, null, 2), "utf8")
        console.log("Successfully updated supported_tokens.json with token information.")
    } catch (err) {
        console.error("Error writing to supported_tokens.json:", err)
    }
}

updateEnv().catch(console.error)
