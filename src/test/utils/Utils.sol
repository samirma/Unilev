// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@solmate/tokens/ERC20.sol";
import "@uniswapCore/contracts/UniswapV3Factory.sol";
import "../mocks/MockV3Aggregator.sol";
import "../../UniswapV3Helper.sol";
import {UniswapV3Pool} from "@uniswapCore/contracts/UniswapV3Pool.sol";

contract Utils is Test {
    using stdStorage for StdStorage;

    UniswapV3Factory factory = UniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function getPool(address tokenA, address tokenB, uint24 fee) public view returns (address) {
        address out = factory.getPool(tokenA, tokenB, fee);
        console.log("pool address: %s", out);
        return out;
    }

    function writeTokenBalance(address who, address token, uint256 amt) public {
        stdstore.target(token).sig(ERC20(token).balanceOf.selector).with_key(who).checked_write(
            amt
        );
    }

    function setPrice(
        MockV3Aggregator mockV3Aggregator,
        UniswapV3Pool pool,
        UniswapV3Helper uniswapV3Helper,
        uint8 token0Decimals
    ) public returns (uint160 price, uint160 sqrtPriceX96) {
        (sqrtPriceX96, , , , , , ) = pool.slot0();

        price = uniswapV3Helper.sqrtPriceX96ToPrice(sqrtPriceX96, token0Decimals);

        mockV3Aggregator.updateAnswer(int(int160(price)));
        mockV3Aggregator.latestRoundData();

        assertApproxEqRel(price, sqrtPriceX96, 0.01e18);
    }
}
