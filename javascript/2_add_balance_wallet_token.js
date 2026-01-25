// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It swaps ETH to get approximately $100 equivalent of each token, using the deployed UniswapV3Helper.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getAbi, getErc20Abi, getEnvVars, setupProviderAndWallet } = require("./utils");
const { logWalletBalances } = require("./balance");

async function main() {
  const env = getEnvVars();
  const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

  console.log(`Fetching balances for wallet: ${wallet.address}`);
  console.log("----------------------------------------------------\n");

  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const positionsAbi = getAbi("Positions");
  const liquidityPoolFactoryAbi = getAbi("LiquidityPoolFactory");
  const liquidityPoolAbi = getAbi("LiquidityPool");
  const uniswapV3HelperAbi = getAbi("UniswapV3Helper");

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, wallet);
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

    const ethPriceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(env.WETH);
    console.log(`ETH Price: $${ethers.formatUnits(ethPriceInUsd, 18)}`);

    const ethAmountFor100USD = (targetUsdValue * BigInt(1e18)) / ethPriceInUsd;
    console.log(`ETH Amount for $100: ${ethers.formatEther(ethAmountFor100USD)} ETH`);

    console.log("\nperforming Swaps...");

    const swapFee = 3000;
    let nonce = await provider.getTransactionCount(wallet.address);

    const totalEthNeeded = ethAmountFor100USD * 4n;
    console.log(`Total ETH to wrap: ${ethers.formatEther(totalEthNeeded)} ETH`);

    console.log("Wrapping ETH...");
    const txWrap = await wethContract.deposit({ value: totalEthNeeded, nonce: nonce++ });
    await txWrap.wait();
    console.log("- Wrapped ETH to WETH");

    const amountToApprove = ethAmountFor100USD * 3n;
    console.log(`Approving Helper to spend ${ethers.formatEther(amountToApprove)} WETH...`);
    const txApprove = await wethContract.approve(env.UNISWAPV3HELPER_ADDRESS, amountToApprove, { nonce: nonce++ });
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
        env.WETH,
        p.token,
        swapFee,
        ethAmountFor100USD,
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