// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@solmate/tokens/ERC20.sol";
import "@uniswapCore/contracts/UniswapV3Factory.sol";
import "../mocks/MockV3Aggregator.sol";
import "../../PriceFeedL1.sol";
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

    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }

    function setPrice(
        uint160 targetPrice,
        address token0,
        address token1,
        uint24 fee,
        MockV3Aggregator mockV3Aggregator0,
        MockV3Aggregator mockV3Aggregator1,
        UniswapV3Helper uniswapV3Helper
    ) public returns (uint160 price, uint160 sqrtPriceX96) {
        UniswapV3Pool pool = UniswapV3Pool(getPool(token0, token1, fee));
        (sqrtPriceX96, , , , , , ) = pool.slot0();
        uint priceToken0;
        uint priceToken1;
        uint bT0 = ERC20(token0).balanceOf(address(pool));
        uint bT1 = ERC20(token1).balanceOf(address(pool));
        uint precision = (sqrtPriceX96 * 10) / 10000;
        if (targetPrice == 0) {
            price = uniswapV3Helper.sqrtPriceX96ToPrice(sqrtPriceX96, ERC20(token0).decimals());

            // set chainlink price
            priceToken0 = (10 ** ERC20(token0).decimals());
            priceToken1 = (priceToken0 * (10 ** uint256(ERC20(token1).decimals()))) / price;
            mockV3Aggregator0.updateAnswer(int(priceToken0));
            mockV3Aggregator1.updateAnswer(int(priceToken1));
        } else {
            // set uniswap price
            uint sqrtPriceX96target = uniswapV3Helper.priceToSqrtPriceX96(
                targetPrice,
                ERC20(token0).decimals()
            );
            // price enslavement
            while (uint(abs(int(int160(sqrtPriceX96) - int(sqrtPriceX96target)))) > precision) {
                uint tradeAmount = sqrtPriceX96target > sqrtPriceX96
                    ? ((bT1 * uint(abs(int(int160(sqrtPriceX96) - int(sqrtPriceX96target))))) /
                        50) / sqrtPriceX96
                    : ((bT0 * uint(abs(int(int160(sqrtPriceX96) - int(sqrtPriceX96target))))) /
                        50) / sqrtPriceX96;
                address tokenToTrade = sqrtPriceX96target > sqrtPriceX96 ? token1 : token0;
                writeTokenBalance(address(this), tokenToTrade, tradeAmount);
                ERC20(tokenToTrade).approve(address(uniswapV3Helper), tradeAmount);
                uniswapV3Helper.swapExactInputSingle(
                    tokenToTrade,
                    tokenToTrade == token0 ? token1 : token0,
                    3000,
                    tradeAmount
                );
                (sqrtPriceX96, , , , , , ) = pool.slot0();

                // console.log("tokenToTrade: %s", tokenToTrade);

                // console.log("sqrtPriceX96target: %d", sqrtPriceX96target);
                // console.log("sqrtPriceX96:       %d", sqrtPriceX96);
                // console.log(
                //     "Price:        %d",
                //     uniswapV3Helper.sqrtPriceX96ToPrice(sqrtPriceX96, ERC20(token0).decimals())
                // );
                // console.log("o: %d", o++);
            }

            // set chainlink price
            priceToken0 = (10 ** ERC20(token0).decimals());
            priceToken1 = (priceToken0 * (10 ** uint256(ERC20(token1).decimals()))) / targetPrice;
            mockV3Aggregator0.updateAnswer(int(priceToken0));
            mockV3Aggregator1.updateAnswer(int(priceToken1));
        }
    }
}
