// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "../interfaces/IUniswapV3.sol";
import {PriceFeedL1} from "../PriceFeedL1.sol";
import {LiquidityPoolFactory} from "../LiquidityPoolFactory.sol";
import {
    Positions__POOL_NOT_OFFICIAL,
    Positions__TOKEN_NOT_SUPPORTED,
    Positions__NO_PRICE_FEED,
    Positions__LEVERAGE_NOT_IN_RANGE,
    Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN,
    Positions__AMOUNT_TO_SMALL,
    Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT,
    Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT
} from "./PositionTypes.sol";

library PositionLogic {
    struct ValidationParams {
        address token0;
        address token1;
        uint24 fee;
        bool isShort;
        uint8 leverage;
        uint256 amount;
        uint256 limitPrice;
        uint256 stopLossPrice;
        address liquidityPoolFactoryUniswapV3;
        address liquidityPoolFactory;
        address priceFeed;
        uint256 maxLeverage;
        uint256 minPositionAmountInUsd;
    }

    struct ValidationResult {
        uint256 price;
        address baseToken;
        address quoteToken;
        bool isBaseToken0;
        address v3Pool;
    }

    function validateOpenPosition(
        ValidationParams memory params
    ) external view returns (ValidationResult memory result) {
        result.v3Pool = address(
            IUniswapV3Factory(params.liquidityPoolFactoryUniswapV3).getPool(
                params.token0,
                params.token1,
                params.fee
            )
        );

        // Cache pool contract to avoid repeated external calls
        IUniswapV3Pool pool = IUniswapV3Pool(result.v3Pool);

        if (pool.factory() != params.liquidityPoolFactoryUniswapV3) {
            revert Positions__POOL_NOT_OFFICIAL(result.v3Pool);
        }

        // Cache token addresses
        address poolToken0 = pool.token0();
        address poolToken1 = pool.token1();

        // check token
        if (poolToken0 != params.token0 && poolToken1 != params.token0) {
            revert Positions__TOKEN_NOT_SUPPORTED(params.token0);
        }

        /**
         * @dev The user need to open a long position by sending
         * the base token and open a short position by depositing the quote token.
         */
        if (params.isShort) {
            result.quoteToken = params.token0;
            result.baseToken = (params.token0 == poolToken0) ? poolToken1 : poolToken0;
        } else {
            result.baseToken = params.token0;
            result.quoteToken = (params.token0 == poolToken0) ? poolToken1 : poolToken0;
        }
        result.isBaseToken0 = (result.baseToken == poolToken0);

        // check if pair is supported by PriceFeed
        if (!PriceFeedL1(params.priceFeed).isPairSupported(result.baseToken, result.quoteToken)) {
            revert Positions__NO_PRICE_FEED(result.baseToken, result.quoteToken);
        }

        result.price = PriceFeedL1(params.priceFeed).getPairLatestPrice(
            result.baseToken,
            result.quoteToken
        );

        // check leverage
        if (params.leverage < 1 || params.leverage > params.maxLeverage) {
            revert Positions__LEVERAGE_NOT_IN_RANGE(params.leverage);
        }
        // when margin position check if token is supported by a LiquidityPool
        if (params.leverage != 1) {
            if (
                params.isShort &&
                LiquidityPoolFactory(params.liquidityPoolFactory).getTokenToLiquidityPools(
                    result.baseToken
                ) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(result.baseToken);
            }
            if (
                !params.isShort &&
                LiquidityPoolFactory(params.liquidityPoolFactory).getTokenToLiquidityPools(
                    result.quoteToken
                ) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(result.quoteToken);
            }
        }

        // check amount
        uint256 humanReadableUsd = PriceFeedL1(params.priceFeed).getAmountInUsd(
            params.token0,
            params.amount
        ); // Returns value with 18 decimals
        if (humanReadableUsd < params.minPositionAmountInUsd) {
            revert Positions__AMOUNT_TO_SMALL(
                IERC20Metadata(params.token0).symbol(),
                humanReadableUsd,
                params.amount
            );
        }

        if (params.isShort) {
            if (params.limitPrice > result.price && params.limitPrice != 0) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(params.limitPrice);
            }
            if (params.stopLossPrice < result.price && params.stopLossPrice != 0) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(params.stopLossPrice);
            }
        } else {
            if (params.limitPrice < result.price && params.limitPrice != 0) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(params.limitPrice);
            }
            if (params.stopLossPrice > result.price && params.stopLossPrice != 0) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(params.stopLossPrice);
            }
        }
    }
}
