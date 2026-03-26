// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct TokenInfo {
        address token;
        address priceFeed;
    }

    struct NetworkConfig {
        TokenInfo wrapper;
        TokenInfo[] supportedTokens;
        address nonfungiblePositionManager;
        address swapRouter;
        address liquidityPoolFactoryUniswapV3;
        address treasure;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[1] = getMainnetEthereumConfig();
        chainIdToNetworkConfig[137] = getMainnetPolygonConfig();
        chainIdToNetworkConfig[31337] = getMainnetEthereumConfig(); // Anvil local testing
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getMainnetEthereumConfig()
        internal
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        TokenInfo[] memory tokens = new TokenInfo[](4);

        // WBTC
        tokens[0] = TokenInfo({
            token: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            priceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
        });

        // USDC
        tokens[1] = TokenInfo({
            token: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            priceFeed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        });

        // DAI
        tokens[2] = TokenInfo({
            token: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            priceFeed: 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
        });

        // WETH
        tokens[3] = TokenInfo({
            token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });

        mainnetNetworkConfig = NetworkConfig({
            wrapper: tokens[3],
            supportedTokens: tokens,
            nonfungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            liquidityPoolFactoryUniswapV3: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            treasure: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
        });
    }

    function getMainnetPolygonConfig()
        internal
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        TokenInfo[] memory tokens = new TokenInfo[](5);

        // WBTC
        tokens[0] = TokenInfo({
            token: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            priceFeed: 0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6
        });

        // WETH
        tokens[1] = TokenInfo({
            token: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            priceFeed: 0xF9680D99D6C9589e2a93a78A04A279e509205945
        });

        // USDC
        tokens[2] = TokenInfo({
            token: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359,
            priceFeed: 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
        });

        // DAI
        tokens[3] = TokenInfo({
            token: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            priceFeed: 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D
        });

        // WPOL
        tokens[4] = TokenInfo({
            token: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            priceFeed: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        });

        mainnetNetworkConfig = NetworkConfig({
            wrapper: tokens[4],
            supportedTokens: tokens,
            nonfungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            liquidityPoolFactoryUniswapV3: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            treasure: 0xBB6B5fD8AC1Fa2f4b20Dbd0d4b278b0E64ecA5DA
        });
    }
}
