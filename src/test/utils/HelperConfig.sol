// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address priceFeedETHUSD;
        address priceFeedWBTCUSD;
        address priceFeedUSDCUSD;
        address priceFeedDAIUSD;
        address nonfungiblePositionManager;
        address swapRouter;
        address liquidityPoolFactoryUniswapV3;
        uint256 liquidationReward;
        address addWBTC;
        address addWETH;
        address addUSDC;
        address addDAI;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[1] = getMainnetForkConfig();
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getMainnetForkConfig()
        internal
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            priceFeedETHUSD: 0x5f4eC3Df9cbd43714FE274045F3641370dFf471a, // ETH/USD Mainnet
            priceFeedWBTCUSD: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC/USD Mainnet
            priceFeedUSDCUSD: 0x8fFfFfd4AfB6115b954Fe285BEc579aA0e7f2C83, // USDC/USD Mainnet
            priceFeedDAIUSD: 0xAed0c38402a5d19df6E4835349250d3e92F9416b, // DAI/USD Mainnet
            nonfungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            liquidityPoolFactoryUniswapV3: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            liquidationReward: 10,
            addWBTC: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            addWETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            addUSDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            addDAI: 0x6B175474E89094C44Da98b954EedeAC495271d0F
        });
    }
}
