// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Market.sol";
import "forge-std/Script.sol";

contract InitializeTokens is Script {
    function run() public {
        // Deployed contract addresses
        address marketAddress = 0x907CdA8c588c9C859A6fB4F105593a64599741CB;

        // Polygon supported tokens
        address[] memory tokens = new address[](5);
        address[] memory priceFeeds = new address[](5);

        // WBTC
        tokens[0] = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6; // WBTC - already checksummed
        priceFeeds[0] = 0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6; // WBTC/USD feed

        // WETH
        tokens[1] = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        priceFeeds[1] = 0xF9680D99D6C9589e2a93a78A04A279e509205945;

        // USDC
        tokens[2] = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        priceFeeds[2] = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;

        // DAI
        tokens[3] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        priceFeeds[3] = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;

        // WPOL
        tokens[4] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        priceFeeds[4] = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

        vm.startBroadcast();
        Market(marketAddress).initializeTokens(tokens, priceFeeds);
        vm.stopBroadcast();
    }
}
