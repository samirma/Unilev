// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../Positions.sol";
import "../../Market.sol";
import "../../LiquidityPoolFactory.sol";
import "../../LiquidityPool.sol";
import "../../PriceFeedL1.sol";
import {UniswapV3Helper} from "../../UniswapV3Helper.sol";
import "../mocks/MockV3Aggregator.sol";
import "@solmate/tokens/ERC20.sol";

import "@uniswapCore/contracts/UniswapV3Pool.sol";
import {SwapRouter} from "@uniswapPeriphery/contracts/SwapRouter.sol";

import "forge-std/Test.sol";
import "../utils/HelperConfig.sol";

contract TestSetup is Test, HelperConfig {
    UniswapV3Helper public uniswapV3Helper;
    LiquidityPoolFactory public liquidityPoolFactory;
    PriceFeedL1 public priceFeedL1;
    Market public market;
    Positions public positions;
    MockV3Aggregator public mockV3AggregatorWBTCETH;
    MockV3Aggregator public mockV3AggregatorUSDCETH;
    MockV3Aggregator public mockV3AggregatorETHUSD;
    LiquidityPool public lbPoolWBTC;
    LiquidityPool public lbPoolWETH;
    LiquidityPool public lbPoolUSDC;
    UniswapV3Pool public poolUSDCWETH;
    UniswapV3Pool public poolWBTCUSDC;
    UniswapV3Pool public poolWBTCWETH;
    SwapRouter public swapRouter;
    address public alice;
    address public bob;
    address public carol;
    address public deployer;

    HelperConfig.NetworkConfig public conf;

    function setUp() public {
        conf = getActiveNetworkConfig();

        // create users
        deployer = address(0x01);
        alice = address(0x11);
        bob = address(0x21);
        carol = address(0x31);

        // mainnet context
        swapRouter = SwapRouter(payable(conf.swapRouter));
        poolUSDCWETH = UniswapV3Pool(conf.poolUSDCWETH);
        poolWBTCUSDC = UniswapV3Pool(conf.poolWBTCUSDC);
        poolWBTCWETH = UniswapV3Pool(conf.poolWBTCWETH);

        vm.startPrank(deployer);

        /// deployments
        // mocks
        mockV3AggregatorWBTCETH = new MockV3Aggregator(18, 1 ether); // 1 WBTC = 1 ETH
        mockV3AggregatorUSDCETH = new MockV3Aggregator(18, 1e15); // 1 USDC = 0,0001 ETH
        mockV3AggregatorETHUSD = new MockV3Aggregator(8, 100000000000000e8); // 1 ETH = 1000 USD

        // contracts
        uniswapV3Helper = new UniswapV3Helper(conf.nonfungiblePositionManager, conf.swapRouter);
        priceFeedL1 = new PriceFeedL1(address(mockV3AggregatorETHUSD), conf.addWETH);
        liquidityPoolFactory = new LiquidityPoolFactory();
        positions = new Positions(
            address(priceFeedL1),
            address(liquidityPoolFactory),
            conf.liquidityPoolFactoryUniswapV3,
            address(uniswapV3Helper),
            conf.liquidationReward
        );
        market = new Market(
            address(positions),
            address(liquidityPoolFactory),
            address(priceFeedL1),
            deployer
        );

        /// configurations
        // add position addres to the factory
        liquidityPoolFactory.addPositionsAddress(address(positions));

        // transfer ownership
        positions.transferOwnership(address(market));
        liquidityPoolFactory.transferOwnership(address(market));
        priceFeedL1.transferOwnership(address(market));

        // create liquidity pools
        lbPoolWBTC = LiquidityPool(market.createLiquidityPool(conf.addWBTC));
        lbPoolWETH = LiquidityPool(market.createLiquidityPool(conf.addWETH));
        lbPoolUSDC = LiquidityPool(market.createLiquidityPool(conf.addUSDC));

        // add price feeds
        market.addPriceFeed(conf.addWBTC, address(mockV3AggregatorWBTCETH));
        market.addPriceFeed(conf.addUSDC, address(mockV3AggregatorUSDCETH));
        vm.stopPrank();
    }
}
