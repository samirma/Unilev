const { ethers } = require("ethers")
const {
    getErc20Abi,
    getEnvVars,
    setupProviderAndWallet,
    getUniswapV3HelperAbi,
    getSupportedTokens,
} = require("./utils")

async function main() {
    const env = getEnvVars()
    const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY)

    const supportedTokens = getSupportedTokens()
    const wrapperAddress = supportedTokens.wrapper
    const usdcAddress = supportedTokens.USDC

    const wrapperContract = new ethers.Contract(wrapperAddress, getErc20Abi(), wallet)
    const uniswapV3Helper = new ethers.Contract(
        env.UNISWAPV3HELPER_ADDRESS,
        getUniswapV3HelperAbi(),
        wallet
    )

    console.log("Wrapping 4 POL...")
    const amountToWrap = ethers.parseEther("4")
    const txWrap = await wrapperContract.deposit({ value: amountToWrap })
    await txWrap.wait()
    console.log("- Wrapped 2 POL")

    console.log("Approving Helper...")
    const txApprove = await wrapperContract.approve(env.UNISWAPV3HELPER_ADDRESS, amountToWrap)
    await txApprove.wait()
    console.log("- Approved Helper")

    console.log("Swapping WPOL for USDC...")
    const txSwap = await uniswapV3Helper.swapExactInputSingle(
        wrapperAddress,
        usdcAddress,
        3000,
        amountToWrap,
        0n
    )
    await txSwap.wait()
    console.log("- Swapped Complete")

    const usdcContract = new ethers.Contract(usdcAddress, getErc20Abi(), wallet)
    const balance = await usdcContract.balanceOf(wallet.address)
    console.log(`Final USDC Balance: ${ethers.formatUnits(balance, 6)} USDC`)
}

main().catch(console.error)
