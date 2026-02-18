/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    RPC_URL: process.env.RPC_URL,
    WETH: process.env.WETH,
    DAI: process.env.DAI,
    USDC: process.env.USDC,
    WBTC: process.env.WBTC,
    PRICEFEEDL1_ADDRESS: process.env.PRICEFEEDL1_ADDRESS,
    POSITIONS_ADDRESS: process.env.POSITIONS_ADDRESS,
    MARKET_ADDRESS: process.env.MARKET_ADDRESS,
    LIQUIDITYPOOLFACTORY_ADDRESS: process.env.LIQUIDITYPOOLFACTORY_ADDRESS,
    FEEMANAGER_ADDRESS: process.env.FEEMANAGER_ADDRESS,
  },
};

export default nextConfig;
