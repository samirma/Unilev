// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Positions} from "../../src/Positions.sol";
import {Market} from "../../src/Market.sol";
import {LiquidityPoolFactory} from "../../src/LiquidityPoolFactory.sol";
import {LiquidityPool} from "../../src/LiquidityPool.sol";
import {PriceFeedL1} from "../../src/PriceFeedL1.sol";
import {UniswapV3Helper} from "../../src/UniswapV3Helper.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import {HelperConfig} from "../utils/HelperConfig.sol";
import {Utils} from "./Utils.sol";

contract TestSetupMock is Test, HelperConfig, Utils {
    UniswapV3Helper public uniswapV3Helper;
    LiquidityPoolFactory public liquidityPoolFactory;
    PriceFeedL1 public priceFeedL1;
    Market public market;
    Positions public positions;
    MockV3Aggregator public mockV3AggregatorWbtcUsd;
    MockV3Aggregator public mockV3AggregatorUsdcUsd;
    MockV3Aggregator public mockV3AggregatorDaiUsd;
    MockV3Aggregator public mockV3AggregatorEthUsd;
    LiquidityPool public lbPoolWbtc;
    LiquidityPool public lbPoolWeth;
    LiquidityPool public lbPoolUsdc;
    LiquidityPool public lbPoolDai;

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

        vm.startPrank(deployer);

        /// deployments
        // mocks - Chainlink USD feeds usually have 8 decimals
        mockV3AggregatorWbtcUsd = new MockV3Aggregator(8, 60000 * 1e8); // 1 WBTC = $60,000
        mockV3AggregatorUsdcUsd = new MockV3Aggregator(8, 1 * 1e8); // 1 USDC = $1
        mockV3AggregatorDaiUsd = new MockV3Aggregator(8, 1 * 1e8); // 1 DAI = $1
        mockV3AggregatorEthUsd = new MockV3Aggregator(8, 3000 * 1e8); // 1 ETH = $3000

        // contracts
        uniswapV3Helper = new UniswapV3Helper(conf.swapRouter);
        priceFeedL1 = new PriceFeedL1();
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
        lbPoolWbtc = LiquidityPool(market.createLiquidityPool(conf.addWbtc));
        lbPoolWeth = LiquidityPool(market.createLiquidityPool(conf.addWeth));
        lbPoolUsdc = LiquidityPool(market.createLiquidityPool(conf.addUsdc));
        lbPoolDai = LiquidityPool(market.createLiquidityPool(conf.addDai));

        // add price feeds
        market.addPriceFeed(conf.addWbtc, address(mockV3AggregatorWbtcUsd));
        market.addPriceFeed(conf.addUsdc, address(mockV3AggregatorUsdcUsd));
        market.addPriceFeed(conf.addDai, address(mockV3AggregatorDaiUsd));
        market.addPriceFeed(conf.addWeth, address(mockV3AggregatorEthUsd));

        vm.stopPrank();
        vm.stopPrank();

        // add liquidity to a pool to be able to open a short position
        vm.startPrank(bob);
        writeTokenBalance(bob, conf.addWbtc, 10e8);
        writeTokenBalance(bob, conf.addWeth, 100e18);
        writeTokenBalance(bob, conf.addUsdc, 10000000e6);
        writeTokenBalance(bob, conf.addDai, 10000000e6);

        IERC20(conf.addWbtc).approve(address(lbPoolWbtc), 10e8);
        IERC20(conf.addWeth).approve(address(lbPoolWeth), 100e18);
        IERC20(conf.addUsdc).approve(address(lbPoolUsdc), 10000000e6);
        IERC20(conf.addDai).approve(address(lbPoolDai), 10000000e6);

        lbPoolWbtc.deposit(10e8, bob);
        lbPoolWeth.deposit(100e18, bob);
        lbPoolUsdc.deposit(10000000e6, bob);
        lbPoolDai.deposit(10000000e6, bob);

        vm.stopPrank();
    }
}
