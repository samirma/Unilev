// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Positions.sol";
import "../../src/Market.sol";
import "../../src/LiquidityPoolFactory.sol";
import "../../src/LiquidityPool.sol";
import "../../src/PriceFeedL1.sol";
import {UniswapV3Helper} from "../../src/UniswapV3Helper.sol";
import "../mocks/MockV3Aggregator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswapCore/contracts/UniswapV3Pool.sol";
import {SwapRouter} from "@uniswapPeriphery/contracts/SwapRouter.sol";

import "forge-std/Test.sol";
import "../utils/HelperConfig.sol";
import {Utils} from "./Utils.sol";

contract TestSetup is Test, HelperConfig, Utils {
    UniswapV3Helper public uniswapV3Helper;
    LiquidityPoolFactory public liquidityPoolFactory;
    PriceFeedL1 public priceFeedL1;
    Market public market;
    Positions public positions;
    MockV3Aggregator public mockV3AggregatorWBTCUSD;
    MockV3Aggregator public mockV3AggregatorUSDCUSD;
    MockV3Aggregator public mockV3AggregatorDAIUSD;
    MockV3Aggregator public mockV3AggregatorETHUSD;
    LiquidityPool public lbPoolWBTC;
    LiquidityPool public lbPoolWETH;
    LiquidityPool public lbPoolUSDC;
    LiquidityPool public lbPoolDAI;

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

        vm.startPrank(deployer);

        /// deployments
        // mocks - Chainlink USD feeds usually have 8 decimals
        mockV3AggregatorWBTCUSD = new MockV3Aggregator(8, 60000 * 1e8); // 1 WBTC = $60,000
        mockV3AggregatorUSDCUSD = new MockV3Aggregator(8, 1 * 1e8); // 1 USDC = $1
        mockV3AggregatorDAIUSD = new MockV3Aggregator(8, 1 * 1e8); // 1 DAI = $1
        mockV3AggregatorETHUSD = new MockV3Aggregator(8, 3000 * 1e8); // 1 ETH = $3000

        // contracts
        uniswapV3Helper = new UniswapV3Helper(conf.nonfungiblePositionManager, conf.swapRouter);
        priceFeedL1 = new PriceFeedL1();
        liquidityPoolFactory = new LiquidityPoolFactory();
        positions = new Positions(
            address(priceFeedL1),
            address(liquidityPoolFactory),
            conf.liquidityPoolFactoryUniswapV3,
            conf.nonfungiblePositionManager,
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
        lbPoolDAI = LiquidityPool(market.createLiquidityPool(conf.addDAI));

        // add price feeds
        market.addPriceFeed(conf.addWBTC, conf.priceFeedWBTCUSD);
        market.addPriceFeed(conf.addUSDC, conf.priceFeedUSDCUSD);
        market.addPriceFeed(conf.addDAI, conf.priceFeedDAIUSD);
        market.addPriceFeed(conf.addWETH, conf.priceFeedETHUSD);
        vm.stopPrank();

        // add liquidity to a pool to be able to open a short position
        vm.startPrank(bob);
        writeTokenBalance(bob, conf.addWBTC, 10e8);
        writeTokenBalance(bob, conf.addWETH, 100e18);
        writeTokenBalance(bob, conf.addUSDC, 10000000e6);
        writeTokenBalance(bob, conf.addDAI, 10000000e6);

        IERC20(conf.addWBTC).approve(address(lbPoolWBTC), 10e8);
        IERC20(conf.addWETH).approve(address(lbPoolWETH), 100e18);
        IERC20(conf.addUSDC).approve(address(lbPoolUSDC), 10000000e6);
        IERC20(conf.addDAI).approve(address(lbPoolDAI), 10000000e6);

        lbPoolWBTC.deposit(10e8, bob);
        lbPoolWETH.deposit(100e18, bob);
        lbPoolUSDC.deposit(10000000e6, bob);
        lbPoolDAI.deposit(10000000e6, bob);

        vm.stopPrank();
    }
}
