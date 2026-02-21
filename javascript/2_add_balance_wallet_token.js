// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It swaps ETH to get approximately $100 equivalent of each token, using the deployed UniswapV3Helper.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getErc20Abi, getEnvVars, setupProviderAndWallet, getPriceFeedL1Abi, getPositionsAbi, getLiquidityPoolFactoryAbi, getLiquidityPoolAbi, getUniswapV3HelperAbi } = require("./utils");
const { logWalletBalances } = require("./balance");

async function main() {
  const env = getEnvVars();
  const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

  console.log(`Fetching balances for wallet: ${wallet.address}`);
  console.log("----------------------------------------------------\n");

  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getPriceFeedL1Abi();
  const positionsAbi = getPositionsAbi();
  const liquidityPoolFactoryAbi = getLiquidityPoolFactoryAbi();
  const liquidityPoolAbi = getLiquidityPoolAbi();
  const uniswapV3HelperAbi = getUniswapV3HelperAbi();

  const wrapperAddress = env.WRAPPER_ADDRESS;
  const wrapperContract = new ethers.Contract(wrapperAddress, erc20Abi, wallet);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, provider);

  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);
  const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);

  const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY();
  const liquidityPoolFactoryContract = new ethers.Contract(liquidityPoolFactoryAddress, liquidityPoolFactoryAbi, provider);

  try {
    console.log(`Attaching to UniswapV3Helper at ${env.UNISWAPV3HELPER_ADDRESS}...`);
    const uniswapV3Helper = new ethers.Contract(env.UNISWAPV3HELPER_ADDRESS, uniswapV3HelperAbi, wallet);

    console.log("\nCalculating ETH amount for $100...");
    const targetUsdValue = ethers.parseUnits("100", 18);

    const wrapperPriceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(wrapperAddress);
    console.log(`Wrapper Token Price: $${ethers.formatUnits(wrapperPriceInUsd, 18)}`);

    const wrapperAmountFor100USD = (targetUsdValue * BigInt(1e18)) / wrapperPriceInUsd;
    console.log(`Wrapper Amount for $100: ${ethers.formatEther(wrapperAmountFor100USD)}`);

    console.log("\nperforming Swaps...");

    const swapFee = 3000;
    let nonce = await provider.getTransactionCount(wallet.address);

    const totalWrapperNeeded = wrapperAmountFor100USD * 4n;
    console.log(`Total wrapper to wrap: ${ethers.formatEther(totalWrapperNeeded)}`);

    console.log("Wrapping native token...");
    const txWrap = await wrapperContract.deposit({ value: totalWrapperNeeded, nonce: nonce++ });
    await txWrap.wait();
    console.log("- Wrapped native token");

    const amountToApprove = wrapperAmountFor100USD * 3n;
    console.log(`Approving Helper to spend ${ethers.formatEther(amountToApprove)} wrapper token...`);
    const txApprove = await wrapperContract.approve(env.UNISWAPV3HELPER_ADDRESS, amountToApprove, { nonce: nonce++ });
    await txApprove.wait();
    console.log("- Approved Helper");

    const swapParams = [
      { token: env.DAI, name: "DAI" },
      { token: env.USDC, name: "USDC" },
      { token: env.WBTC, name: "WBTC" }
    ];

    for (const p of swapParams) {
      console.log(`Swapping WETH for ${p.name}...`);
      const tx = await uniswapV3Helper.swapExactInputSingle(
        wrapperAddress,
        p.token,
        swapFee,
        wrapperAmountFor100USD,
        0n,
        { nonce: nonce++ }
      );
      await tx.wait();
      console.log(`- Swapped WETH for ${p.name}`);
    }

    console.log("\nUpdated Token Balances:");
    await logWalletBalances(env, provider, wallet);

  } catch (error) {
    console.error("\n❌ An error occurred while fetching balances:");
    console.error(error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});