// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Positions.sol";
import "../src/Market.sol";
import "../src/LiquidityPoolFactory.sol";
import "../src/LiquidityPool.sol";
import "../src/PriceFeedL1.sol";
import {UniswapV3Helper} from "../src/UniswapV3Helper.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol"; // Added for logging
import "../test/utils/HelperConfig.sol";

contract Deployments is Script, HelperConfig {
    UniswapV3Helper public uniswapV3Helper;
    LiquidityPoolFactory public liquidityPoolFactory;
    PriceFeedL1 public priceFeedL1;
    Market public market;
    Positions public positions;
    LiquidityPool public lbPoolWBTC;
    LiquidityPool public lbPoolWETH;
    LiquidityPool public lbPoolUSDC;
    LiquidityPool public lbPoolDAI; // Added for DAI

    address public alice;
    address public bob;
    address public carol;
    address public deployer;

    HelperConfig.NetworkConfig public conf;

    function run() public {
        conf = getActiveNetworkConfig();

        // Logging statements to debug configuration
        console.log("--- Debug Logs ---");
        console.log("Using priceFeedETHUSD:", conf.priceFeedETHUSD);
        console.log("Using priceFeedWBTCUSD:", conf.priceFeedWBTCUSD);
        console.log("Using priceFeedUSDCUSD:", conf.priceFeedUSDCUSD);
        console.log("Using priceFeedDAIUSD:", conf.priceFeedDAIUSD);
        console.log("--- End Debug Logs ---");

        vm.startBroadcast();

        /// deployments
        // contracts
        uniswapV3Helper = new UniswapV3Helper(conf.swapRouter);
        priceFeedL1 = new PriceFeedL1();
        liquidityPoolFactory = new LiquidityPoolFactory();
        positions = new Positions(
            address(priceFeedL1),
            address(liquidityPoolFactory),
            conf.liquidityPoolFactoryUniswapV3,
            address(uniswapV3Helper),
            conf.treasure
        );
        market = new Market(
            address(positions),
            address(liquidityPoolFactory),
            address(priceFeedL1),
            msg.sender
        );

        /// configurations
        // add position address to the factory
        liquidityPoolFactory.addPositionsAddress(address(positions));

        // transfer ownership
        positions.transferOwnership(address(market));
        liquidityPoolFactory.transferOwnership(address(market));
        priceFeedL1.transferOwnership(address(market));

        // create liquidity pools
        lbPoolWBTC = LiquidityPool(market.createLiquidityPool(conf.addWBTC));
        lbPoolWETH = LiquidityPool(market.createLiquidityPool(conf.addWETH));
        lbPoolUSDC = LiquidityPool(market.createLiquidityPool(conf.addUSDC));
        lbPoolDAI = LiquidityPool(market.createLiquidityPool(conf.addDAI)); // Added for DAI

        // add price feeds
        market.addPriceFeed(conf.addWBTC, conf.priceFeedWBTCUSD);
        market.addPriceFeed(conf.addUSDC, conf.priceFeedUSDCUSD);
        market.addPriceFeed(conf.addWETH, conf.priceFeedETHUSD);
        market.addPriceFeed(conf.addDAI, conf.priceFeedDAIUSD); // Added for DAI

        vm.stopBroadcast();
    }
}
