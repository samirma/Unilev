// This script connects to the blockchain and fetches the balance of ETH, WETH, DAI, USDC, and WBTC for a given wallet.
// It now uses the PriceFeedL1 contract to fetch the USD price of each asset and calculate the USD value of the balances.
// Configuration is loaded from a .env file.

const { ethers } = require("ethers");
const { getAbi, getErc20Abi, getTokenBalance, getEnvVars, setupProviderAndWallet } = require("./utils");

function logHeader(title, subtitle = "") {
  console.log("\n========================================================");
  console.log(` ${title}`);
  if (subtitle) console.log(` ${subtitle}`);
  console.log("========================================================");
}

async function logWalletBalances(env, provider, wallet) {
  logHeader("💰 WALLET BALANCES", `Address: ${wallet.address}`);

  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

  const ethBalance = await provider.getBalance(wallet.address);
  const formattedEthBalance = ethers.formatEther(ethBalance);
  const ethUsdValueBigInt = await priceFeedL1Contract.getAmountInUsd(env.WETH, ethBalance);
  const ethUsdValue = parseFloat(ethers.formatUnits(ethUsdValueBigInt, 18)).toFixed(2);
  console.log(`  ETH    : ${formattedEthBalance.padEnd(20)} (~$ ${ethUsdValue} USD)`);

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, provider);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, provider);

  await getTokenBalance(wethContract, wallet.address, priceFeedL1Contract);
  await getTokenBalance(daiContract, wallet.address, priceFeedL1Contract);
  await getTokenBalance(usdcContract, wallet.address, priceFeedL1Contract);
  await getTokenBalance(wbtcContract, wallet.address, priceFeedL1Contract);
}

async function logPositionBalances(env, provider, wallet) {
  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, provider);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, provider);

  logHeader("📉 POSITION CONTRACT BALANCES", `Address: ${env.POSITIONS_ADDRESS}`);
  await getTokenBalance(wethContract, env.POSITIONS_ADDRESS, priceFeedL1Contract);
  await getTokenBalance(daiContract, env.POSITIONS_ADDRESS, priceFeedL1Contract);
  await getTokenBalance(usdcContract, env.POSITIONS_ADDRESS, priceFeedL1Contract);
  await getTokenBalance(wbtcContract, env.POSITIONS_ADDRESS, priceFeedL1Contract);
}

async function logPoolBalances(env, provider) {
  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const positionsAbi = getAbi("Positions");
  const liquidityPoolFactoryAbi = getAbi("LiquidityPoolFactory");
  const liquidityPoolAbi = getAbi("LiquidityPool");

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, provider);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, provider);

  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);
  const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);

  const liquidityPoolFactoryAddress = await positionsContract.LIQUIDITY_POOL_FACTORY();
  const liquidityPoolFactoryContract = new ethers.Contract(liquidityPoolFactoryAddress, liquidityPoolFactoryAbi, provider);

  logHeader("🏊 LIQUIDITY POOLS");
  const tokens = [
    { contract: wethContract, name: "WETH" },
    { contract: daiContract, name: "DAI" },
    { contract: usdcContract, name: "USDC" },
    { contract: wbtcContract, name: "WBTC" }
  ];

  for (const token of tokens) {
    const tokenAddress = await token.contract.getAddress();
    const poolAddress = await liquidityPoolFactoryContract.getTokenToLiquidityPools(tokenAddress);

    if (poolAddress !== ethers.ZeroAddress) {
      const poolContract = new ethers.Contract(poolAddress, liquidityPoolAbi, provider);
      const rawTotalAsset = await poolContract.rawTotalAsset();
      const decimals = await token.contract.decimals();
      const formattedAsset = ethers.formatUnits(rawTotalAsset, decimals);

      const usdValueBigInt = await priceFeedL1Contract.getAmountInUsd(tokenAddress, rawTotalAsset);
      const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2);

      console.log(`  ${token.name.padEnd(6)} : ${formattedAsset.padEnd(20)} (~$ ${usdValue} USD)`);
    } else {
      console.log(`  ${token.name.padEnd(6)} : Pool Not Found`);
    }
  }
}

async function logTreasureBalances(env, provider) {
  const erc20Abi = getErc20Abi();
  const priceFeedL1Abi = getAbi("PriceFeedL1");
  const positionsAbi = getAbi("Positions");

  const priceFeedL1Contract = new ethers.Contract(env.PRICEFEEDL1_ADDRESS, priceFeedL1Abi, provider);
  const positionsContract = new ethers.Contract(env.POSITIONS_ADDRESS, positionsAbi, provider);

  const treasureAddress = await positionsContract.treasure();

  logHeader("💎 TREASURE CONTRACT BALANCES", `Address: ${treasureAddress}`);

  const ethBalance = await provider.getBalance(treasureAddress);
  const formattedEthBalance = ethers.formatEther(ethBalance);
  const ethUsdValueBigInt = await priceFeedL1Contract.getAmountInUsd(env.WETH, ethBalance);
  const ethUsdValue = parseFloat(ethers.formatUnits(ethUsdValueBigInt, 18)).toFixed(2);
  console.log(`  ETH    : ${formattedEthBalance.padEnd(20)} (~$ ${ethUsdValue} USD)`);

  const wethContract = new ethers.Contract(env.WETH, erc20Abi, provider);
  const daiContract = new ethers.Contract(env.DAI, erc20Abi, provider);
  const usdcContract = new ethers.Contract(env.USDC, erc20Abi, provider);
  const wbtcContract = new ethers.Contract(env.WBTC, erc20Abi, provider);

  await getTokenBalance(wethContract, treasureAddress, priceFeedL1Contract);
  await getTokenBalance(daiContract, treasureAddress, priceFeedL1Contract);
  await getTokenBalance(usdcContract, treasureAddress, priceFeedL1Contract);
  await getTokenBalance(wbtcContract, treasureAddress, priceFeedL1Contract);
}

async function logBalances(env, provider, wallet) {
  try {
    await logWalletBalances(env, provider, wallet);
    await logPositionBalances(env, provider, wallet);
    await logTreasureBalances(env, provider);
    await logPoolBalances(env, provider);
  } catch (error) {
    console.error("\n❌ An error occurred while fetching balances:");
    console.error(error.reason || error);
    throw error;
  }
}

async function main() {
  const env = getEnvVars();
  const { provider, wallet } = setupProviderAndWallet(env.RPC_URL, env.PRIVATE_KEY);
  await logBalances(env, provider, wallet);
}

if (require.main === module) {
  main().catch((error) => {
    console.error("An unexpected error occurred in the main execution:", error);
    process.exit(1);
  });
}

module.exports = { logBalances, logWalletBalances, logPositionBalances, logPoolBalances, logTreasureBalances };