// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It swaps ETH to get approximately $100 equivalent of each token, using the deployed UniswapV3Helper.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getErc20Abi, getEnvVars, setupProviderAndWallet, getPriceFeedL1Abi, getPositionsAbi, getLiquidityPoolFactoryAbi, getLiquidityPoolAbi, getUniswapV3HelperAbi, getSupportedTokens } = require("./utils");
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

  const supportedTokens = getSupportedTokens();
  if (!supportedTokens) {
    console.error("Could not load supported tokens");
    process.exit(1);
  }

  const wrapperAddress = env.WRAPPER_ADDRESS || supportedTokens.wrapper;
  const wrapperContract = new ethers.Contract(wrapperAddress, erc20Abi, wallet);

  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

  try {
    console.log(`Attaching to UniswapV3Helper at ${env.UNISWAPV3HELPER_ADDRESS}...`);
    const uniswapV3Helper = new ethers.Contract(env.UNISWAPV3HELPER_ADDRESS, uniswapV3HelperAbi, wallet);

    console.log("\nCalculating ETH amount for $10...");
    const targetUsdValue = ethers.parseUnits("10", 18);

    const wrapperPriceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(wrapperAddress);
    console.log(`Wrapper Token Price: $${ethers.formatUnits(wrapperPriceInUsd, 18)}`);

    const wrapperAmountFor10USD = (targetUsdValue * BigInt(1e18)) / wrapperPriceInUsd;
    console.log(`Wrapper Amount for $10: ${ethers.formatEther(wrapperAmountFor10USD)}`);

    console.log("\nperforming Swaps...");

    const swapFee = 3000;
    let nonce = await provider.getTransactionCount(wallet.address);

    const swapParams = [];
    const seenAddresses = new Set([wrapperAddress.toLowerCase()]); // Skip wrapper token itself and duplicates

    for (const [symbol, address] of Object.entries(supportedTokens)) {
      if (symbol === "wrapper") continue;

      const lowerAddress = address.toLowerCase();
      if (!seenAddresses.has(lowerAddress)) {
        seenAddresses.add(lowerAddress);
        swapParams.push({ token: address, name: symbol });
      }
    }

    const tokensNeedingSwap = BigInt(swapParams.length);
    const totalWrapperNeeded = wrapperAmountFor10USD * (tokensNeedingSwap + 1n); // +1 to keep some wrapper balance
    console.log(`Total wrapper to wrap: ${ethers.formatEther(totalWrapperNeeded)}`);

    console.log("Wrapping native token...");
    const txWrap = await wrapperContract.deposit({ value: totalWrapperNeeded, nonce: nonce++ });
    await txWrap.wait();
    console.log("- Wrapped native token");

    const amountToApprove = wrapperAmountFor10USD * tokensNeedingSwap;
    console.log(`Approving Helper to spend ${ethers.formatEther(amountToApprove)} wrapper token...`);
    const txApprove = await wrapperContract.approve(env.UNISWAPV3HELPER_ADDRESS, amountToApprove, { nonce: nonce++ });
    await txApprove.wait();
    console.log("- Approved Helper");

    for (const p of swapParams) {
      console.log(`Swapping Wrapper Token for ${p.name}...`);
      const tx = await uniswapV3Helper.swapExactInputSingle(
        wrapperAddress,
        p.token,
        swapFee,
        wrapperAmountFor10USD,
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