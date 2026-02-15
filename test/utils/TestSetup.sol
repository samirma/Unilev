// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Positions} from "../../src/Positions.sol";
import {Market} from "../../src/Market.sol";
import {LiquidityPoolFactory} from "../../src/LiquidityPoolFactory.sol";
import {LiquidityPool} from "../../src/LiquidityPool.sol";
import {PriceFeedL1} from "../../src/PriceFeedL1.sol";
import {UniswapV3Helper} from "../../src/UniswapV3Helper.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {FeeManager} from "../../src/FeeManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import {HelperConfig} from "../../scripts/HelperConfig.sol";
import {Utils} from "./Utils.sol";

contract TestSetup is Test, HelperConfig, Utils {
    UniswapV3Helper public uniswapV3Helper;
    LiquidityPoolFactory public liquidityPoolFactory;
    PriceFeedL1 public priceFeedL1;
    Market public market;
    Positions public positions;
    FeeManager public feeManager;
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

    function setUp() public virtual {
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
        feeManager = new FeeManager(5, 3); // 0.05% treasure fee, 0.03% liquidation reward
        positions = new Positions(
            address(priceFeedL1),
            address(liquidityPoolFactory),
            conf.liquidityPoolFactoryUniswapV3,
            address(uniswapV3Helper),
            conf.treasure,
            address(feeManager)
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

        // Set a longer staleness threshold for fork testing (7 days to account for mainnet fork age)
        // Must be done before transferring ownership
        priceFeedL1.setStalenessThreshold(7 days);
        
        // transfer ownership
        positions.transferOwnership(address(market));
        liquidityPoolFactory.transferOwnership(address(market));
        priceFeedL1.transferOwnership(address(market));

        // create liquidity pools
        lbPoolWbtc = LiquidityPool(market.createLiquidityPool(conf.wbtc));
        lbPoolWeth = LiquidityPool(market.createLiquidityPool(conf.weth));
        lbPoolUsdc = LiquidityPool(market.createLiquidityPool(conf.usdc));
        lbPoolDai = LiquidityPool(market.createLiquidityPool(conf.dai));

        // add price feeds
        market.addPriceFeed(conf.wbtc, conf.priceFeedWbtcUsd);
        market.addPriceFeed(conf.usdc, conf.priceFeedUsdcUsd);
        market.addPriceFeed(conf.dai, conf.priceFeedDaiUsd);
        market.addPriceFeed(conf.weth, conf.priceFeedEthUsd);
        
        vm.stopPrank();

        // add liquidity to a pool to be able to open a short position
        vm.startPrank(bob);
        writeTokenBalance(bob, conf.wbtc, 10e8);
        writeTokenBalance(bob, conf.weth, 100e18);
        writeTokenBalance(bob, conf.usdc, 10000000e6);
        writeTokenBalance(bob, conf.dai, 10000000e6);

        IERC20(conf.wbtc).approve(address(lbPoolWbtc), 10e8);
        IERC20(conf.weth).approve(address(lbPoolWeth), 100e18);
        IERC20(conf.usdc).approve(address(lbPoolUsdc), 10000000e6);
        IERC20(conf.dai).approve(address(lbPoolDai), 10000000e6);

        lbPoolWbtc.deposit(10e8, bob);
        lbPoolWeth.deposit(100e18, bob);
        lbPoolUsdc.deposit(10000000e6, bob);
        lbPoolDai.deposit(10000000e6, bob);

        vm.stopPrank();
    }
}
