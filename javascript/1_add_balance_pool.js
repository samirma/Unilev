// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It swaps ETH to acquire ~$1000 USD worth of each token, and then deposits them into the respective Liquidity Pools.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getAbi, getErc20Abi, getTokenBalance, getEnvVars, setupProviderAndWallet } = require("./utils");
const { logPoolBalances } = require("./balance");

async function main() {
  // --- Environment Setup ---
  const env = getEnvVars();
  const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);

  console.log(`Fetching balances for wallet: ${wallet.address}`);
  console.log("----------------------------------------------------\n");

  // --- Contract Instances ---
  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const positionsAbi = getAbi("Positions");
  const liquidityPoolFactoryAbi = getAbi("LiquidityPoolFactory");
  const liquidityPoolAbi = getAbi("LiquidityPool");
  const uniswapV3HelperAbi = getAbi("UniswapV3Helper");

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, wallet);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, wallet);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, wallet);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, wallet);

  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);
  const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);
  const uniswapV3Helper = new ethers.Contract(env.UNISWAPV3HELPER_ADDRESS, uniswapV3HelperAbi, wallet);

  const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY();
  const liquidityPoolFactoryContract = new ethers.Contract(liquidityPoolFactoryAddress, liquidityPoolFactoryAbi, provider);

  try {

    // --- 1. Calculate Required ETH for Swaps ---
    console.log("Calculating token amounts needed for $1000 each...");
    const targetUsdValue = ethers.parseUnits("1000", 18);

    // Get ETH Price in USD
    const ethPriceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(env.WETH);
    console.log(`ETH Price: $${ethers.formatUnits(ethPriceInUsd, 18)}`);

    // Amount of ETH needed = TargetUSD / ETHPrice
    const ethAmountFor1000USD = (targetUsdValue * BigInt(1e18)) / ethPriceInUsd;
    console.log(`ETH Amount for $1000: ${ethers.formatEther(ethAmountFor1000USD)} ETH`);

    let nonce = await provider.getTransactionCount(wallet.address);

    const tokens = [
      { contract: wethContract, name: "WETH", address: env.WETH, needsSwap: false },
      { contract: daiContract, name: "DAI", address: env.DAI, needsSwap: true },
      { contract: usdcContract, name: "USDC", address: env.USDC, needsSwap: true },
      { contract: wbtcContract, name: "WBTC", address: env.WBTC, needsSwap: true }
    ];

    // Calculate total ETH needed to wrap (1x for WETH deposit + 3x for Swaps)
    const totalEthToWrap = ethAmountFor1000USD * 4n + ethers.parseEther("0.1"); // Add 0.1 ETH buffer

    console.log(`\nRequirements:`);
    console.log(`- Wrap ${ethers.formatEther(totalEthToWrap)} ETH to WETH`);

    // --- 2. Wrap ETH ---
    console.log("\nWrapping ETH...");
    const txWrap = await wethContract.deposit({ value: totalEthToWrap, nonce: nonce++ });
    await txWrap.wait();
    console.log("- Wrapped ETH");

    // --- 3. Approve Uniswap Helper ---
    const totalSwapAmount = ethAmountFor1000USD * 3n;
    console.log(`Approving Uniswap Helper to spend ${ethers.formatEther(totalSwapAmount)} WETH...`);
    const txApproveHelper = await wethContract.approve(env.UNISWAPV3HELPER_ADDRESS, totalSwapAmount, { nonce: nonce++ });
    await txApproveHelper.wait();
    console.log("- Approved Helper");

    const swapFee = 3000; // 0.3%

    // --- 4. Process Each Token (Swap & Deposit) ---
    for (const token of tokens) {
      console.log(`\n----------------------------------------------------`);
      console.log(`Processing ${token.name}...`);

      let tokenAmountToDeposit = 0n;

      if (token.needsSwap) {
        console.log(`- Swapping WETH for ${token.name}...`);
        const txSwap = await uniswapV3Helper.swapExactInputSingle(
          env.WETH,
          token.address,
          swapFee,
          ethAmountFor1000USD,
          { nonce: nonce++ }
        );
        await txSwap.wait();
        console.log(`- Swap Complete.`);

        const priceInUsd = await priceFeedL1Contract.getTokenLatestPriceInUsd(token.address);
        const tokenDecimals = await token.contract.decimals();
        tokenAmountToDeposit = (targetUsdValue * BigInt(10n ** tokenDecimals)) / priceInUsd;

        console.log(`- Calculated Deposit Amount ($1000): ${ethers.formatUnits(tokenAmountToDeposit, tokenDecimals)} ${token.name}`);

        const currentBalance = await token.contract.balanceOf(wallet.address);
        if (currentBalance < tokenAmountToDeposit) {
          console.log(`- Warning: Balance (${ethers.formatUnits(currentBalance, tokenDecimals)}) is slightly less than calculated target. Depositing Max Balance.`);
          tokenAmountToDeposit = currentBalance;
        }

      } else {
        tokenAmountToDeposit = ethAmountFor1000USD;
        console.log(`- Deposit Amount ($1000): ${ethers.formatUnits(tokenAmountToDeposit, 18)} ${token.name}`);
      }

      const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(token.address);
      if (poolAddress === ethers.ZeroAddress) {
        console.log(`- No Liquidity Pool found for ${token.name}`);
        continue;
      }
      console.log(`- Pool Address: ${poolAddress}`);

      console.log(`- Approving Pool...`);
      const txApprovePool = await token.contract.approve(poolAddress, tokenAmountToDeposit, { nonce: nonce++ });
      await txApprovePool.wait();
      console.log(`- Approved Pool.`);

      console.log(`- Depositing...`);
      const liquidityPoolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, wallet);
      const txDeposit = await liquidityPoolContract.deposit(tokenAmountToDeposit, wallet.address, { nonce: nonce++ });
      await txDeposit.wait();
      console.log(`- Deposited.`);
    }


    // --- Fetch and Display Balances ---
    console.log("\n----------------------------------------------------");
    console.log("Final Pool Balances:");
    await logPoolBalances(env, provider, wallet);

  } catch (error) {
    console.error("\n❌ An error occurred while processing:");
    console.error(error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("An unexpected error occurred in the main execution:", error);
  process.exit(1);
});