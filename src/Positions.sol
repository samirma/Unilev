// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswapCore/contracts/libraries/TickMath.sol";
import "@uniswapCore/contracts/UniswapV3Pool.sol";
import "./PriceFeedL1.sol";
import "./LiquidityPoolFactory.sol";
import {UniswapV3Helper} from "./UniswapV3Helper.sol";

error Positions__POSITION_NOT_OPEN(uint256 _posId);
error Positions__POSITION_NOT_LIQUIDABLE_YET(uint256 _posId);
error Positions__POSITION_NOT_OWNED(address _trader, uint256 _posId);
error Positions__POOL_NOT_OFFICIAL(address _v3Pool);
error Positions__TOKEN_NOT_SUPPORTED(address _token);
error Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(address _token);
error Positions__NO_PRICE_FEED(address _token0, address _token1);
error Positions__LEVERAGE_NOT_IN_RANGE(uint8 _leverage);
error Positions__AMOUNT_TO_SMALL(uint256 _amount);
error Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(uint256 _limitPrice);
error Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(uint256 _stopLossPrice);
error Positions__NOT_LIQUIDABLE(uint256 _posId);
error Positions__WAIT_FOR_LIMIT_ORDER_TO_COMPLET(uint256 _posId);
error Positions__TOKEN_RECEIVED_NOT_CONCISTENT(address tokenBorrowed, address tokenReceived);

contract Positions is ERC721, Ownable, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    // Structs
    // prettier-ignore
    struct PositionParams {
        UniswapV3Pool v3Pool;      // Pool to trade
        ERC20 baseToken;           // Token to trade => should be token0 or token1 of v3Pool
        ERC20 quoteToken;          // Token to trade => should be the other token of v3Pool
        uint128 collateralSize;    // Total collateral for the position
        uint128 positionSize;      // Amount (in baseToken if long / quoteToken if short) of token traded
        uint128 liquidationReward; // Amount (in baseToken if long / quoteToken if short) of token to pay to the liquidator, refund if no liquidation
        uint64 timestamp;          // Timestamp of position creation
        bool isShort;              // True if short, false if long
        bool isBaseToken0;         // True if the baseToken is the token0 (in the uniswapV3Pool) 
        uint8 leverage;            // Leverage of position => 0 if no leverage
        uint256 totalBorrow;       // Total borrow in baseToken if long or quoteToken if short
        uint256 hourlyFees;        // Fees to pay every hour on the borrowed amount => 0 if no leverage
        uint256 breakEvenLimit;    // After this limit the position is undercollateralize => 0 if no leverage or short
        uint160 limitPrice;        // Limit order price => 0 if no limit order
        uint256 stopLossPrice;     // Stop loss price => 0 if no stop loss
        uint256 tokenIdLiquidity;  // TokenId of the liquidity position NFT => 0 if no liquidity position
    }

    // Variables
    uint256 public constant LIQUIDATION_THRESHOLD = 1000; // 10% of margin
    uint256 public constant MIN_POSITION_AMOUNT_IN_USD = 100; // To avoid DOS attack
    uint256 public constant MAX_LEVERAGE = 3;
    uint256 public constant BORROW_FEE = 20; // 0.2% when opening a position
    uint256 public constant BORROW_FEE_EVERY_HOURS = 1; // 0.01% : assets borrowed/total assets in pool * 0.01%
    uint256 public constant ORACLE_DECIMALS_USD = 10e8; // Chainlink decimals for USD
    uint256 public immutable LIQUIDATION_REWARD; // 10 USD : //! to be changed depending of the blockchain average gas price
    string private constant BASE_SVG =
        "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='black' /><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    LiquidityPoolFactory public immutable liquidityPoolFactory;
    PriceFeedL1 public immutable priceFeed;
    UniswapV3Helper public immutable uniswapV3Helper;
    address public immutable liquidityPoolFactoryUniswapV3;

    uint256 public posId;
    uint256 public totalNbPos;
    mapping(uint256 => PositionParams) public openPositions;

    constructor(
        address _market,
        address _priceFeed,
        address _liquidityPoolFactory,
        address _liquidityPoolFactoryUniswapV3,
        address _uniswapV3Helper,
        uint256 _liquidationReward
    ) ERC721("Uniswap-MAX", "UNIMAX") {
        transferOwnership(_market);
        liquidityPoolFactoryUniswapV3 = _liquidityPoolFactoryUniswapV3;
        liquidityPoolFactory = LiquidityPoolFactory(_liquidityPoolFactory);
        priceFeed = PriceFeedL1(_priceFeed);
        uniswapV3Helper = UniswapV3Helper(_uniswapV3Helper);
        LIQUIDATION_REWARD = _liquidationReward * ORACLE_DECIMALS_USD;
    }

    modifier isPositionOpen(uint256 _posId) {
        if (_exists(_posId)) {
            revert Positions__POSITION_NOT_OPEN(_posId);
        }
        _;
    }

    modifier isPositionOwned(address _trader, uint256 _posId) {
        if (ownerOf(_posId) != _trader) {
            revert Positions__POSITION_NOT_OWNED(_trader, _posId);
        }
        _;
    }
    modifier isLiquidable(uint256 _posId) {
        if (getPositionState(_posId) == 2) {
            revert Positions__POSITION_NOT_LIQUIDABLE_YET(_posId);
        }
        _;
    }

    // --------------- ERC721 Zone ---------------

    function safeMint(address to) private returns (uint256) {
        uint256 _posId = posId;
        ++posId;
        _safeMint(to, _posId);
        return _posId;
    }

    function safeBurn(uint256 _posId) private {
        _burn(_posId);
    }

    function tokenURI(
        uint256 _posId
    ) public view virtual override isPositionOpen(_posId) returns (string memory) {
        string memory json = Base64.encode(
            bytes(string.concat(tokenURIIntro(_posId), tokenURIAttributes(openPositions[_posId])))
        );

        return string.concat("data:application/json;base64,", json);
    }

    function tokenURIIntro(uint256 _tokenId) private pure returns (string memory) {
        return
            string.concat(
                '{"name": "Uniswap-Max Position #',
                Strings.toString(_tokenId),
                '", "description": "This NFT represent a position on Uniswap-Max. The owner can close or edit the position.", "image": "',
                imageURI(_tokenId)
            );
    }

    function tokenURIAttributes(
        PositionParams memory _position
    ) private view returns (string memory) {
        string[2] memory parts = [
            // To avoid stack too deep error
            string.concat(
                '", "attributes": [ { "trait_type": "Tokens", "value": "',
                _position.baseToken.name(),
                "/",
                _position.quoteToken.name(),
                '"}, { "trait_type": "Amount", "value": "',
                Strings.toString(_position.positionSize),
                '"} , { "trait_type": "Direction", "value": "',
                _position.isShort ? "Short" : "Long",
                '"}, { "trait_type": "Leverage", "value": "',
                Strings.toString(_position.leverage)
            ),
            string.concat(
                '"}, { "trait_type": "Limit Price", "value": "',
                Strings.toString(_position.limitPrice),
                '"}, { "trait_type": "Stop Loss Price", "value": "',
                Strings.toString(_position.stopLossPrice),
                '"}]}'
            )
        ];

        return string.concat(parts[0], parts[1]);
    }

    function imageURI(uint256 _tokenId) private pure returns (string memory) {
        string memory svg = string.concat(
            BASE_SVG,
            "UNISWAP-MAX #",
            Strings.toString(_tokenId),
            "</text></svg>"
        );

        return string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(svg)));
    }

    // --------------- Trader Zone ---------------

    function openPosition(
        address _trader,
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint128 _amount,
        uint160 _limitPrice,
        uint256 _stopLossPrice
    ) external onlyOwner returns (uint256) {
        // Check params
        (
            uint256 price,
            address baseToken,
            address quoteToken,
            bool isBaseToken0
        ) = checkPositionParams(
                _v3Pool,
                _token,
                _isShort,
                _leverage,
                _amount,
                _limitPrice,
                _stopLossPrice
            );
        bool isMargin = _leverage != 1 || _isShort;

        // transfer funds to the contract (trader need to approve first)
        ERC20(_token).safeTransferFrom(_trader, address(this), _amount);

        // Compute parameters
        uint256 breakEvenLimit;
        uint256 totalBorrow;
        uint256 hourlyFees;

        // take opening fees
        uint128 liquidationReward = uint128(
            (LIQUIDATION_REWARD * (10 ** uint256(ERC20(_token).decimals()))) /
                (PriceFeedL1(priceFeed).getTokenLatestPriceInUSD(_token))
        );
        _amount = _amount - liquidationReward;

        if (isMargin) {
            if (_isShort) {
                breakEvenLimit = price + (price * (10000 / _leverage)) / 10000;
                totalBorrow = ((_amount * (10 ** ERC20(baseToken).decimals())) / price) * _leverage; // Borrow baseToken
            } else {
                breakEvenLimit = price - (price * (10000 / _leverage)) / 10000;
                totalBorrow =
                    (_amount * (_leverage - 1) * price) /
                    (10 ** ERC20(baseToken).decimals()); // Borrow quoteToken
            }
            uint128 openingFees = (uint128(totalBorrow * BORROW_FEE)) / 10000;
            totalBorrow = (uint128(totalBorrow * (10000 - BORROW_FEE))) / 10000;
            address cacheLiquidityPoolToUse = LiquidityPoolFactory(liquidityPoolFactory)
                .getTokenToLiquidityPools(_isShort ? quoteToken : baseToken);

            _amount = _amount - openingFees;
            ERC20(_token).safeApprove(cacheLiquidityPoolToUse, openingFees);
            LiquidityPool(cacheLiquidityPoolToUse).refund(0, openingFees, 0);

            // fees computation
            uint256 decTokenBorrowed = _isShort
                ? ERC20(baseToken).decimals()
                : ERC20(quoteToken).decimals();
            hourlyFees =
                (((totalBorrow * decTokenBorrowed) /
                    LiquidityPool(cacheLiquidityPoolToUse).rawTotalAsset()) *
                    BORROW_FEE_EVERY_HOURS) /
                10000;

            // Borrow funds from the pool
            LiquidityPool(cacheLiquidityPoolToUse).borrow(totalBorrow);
        } else {
            hourlyFees = 0;
            breakEvenLimit = 0;
            totalBorrow = 0;
        }

        // do the trade on Uniswap
        uint256 tokenIdLiquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 amountBorrow;
        int24 tickUpper;
        int24 tickLower;

        if (_isShort) {
            amountBorrow = uniswapV3Helper.swapExactInputSingle(
                baseToken,
                quoteToken,
                UniswapV3Pool(_v3Pool).fee(),
                totalBorrow
            );

            if (_limitPrice != 0) {
                tickUpper = TickMath.getTickAtSqrtRatio(
                    uniswapV3Helper.priceToSqrtPriceX96(
                        _limitPrice,
                        isBaseToken0 ? ERC20(baseToken).decimals() : ERC20(quoteToken).decimals()
                    )
                );
                tickLower = tickUpper + 1;

                (tokenIdLiquidity, , amount0, amount1) = uniswapV3Helper.mintPosition(
                    UniswapV3Pool(_v3Pool),
                    isBaseToken0 ? 0 : amountBorrow,
                    isBaseToken0 ? amountBorrow : 0,
                    tickLower,
                    tickUpper
                );
            }
        } else {
            if (_leverage != 0) {
                amountBorrow = uniswapV3Helper.swapExactInputSingle(
                    quoteToken,
                    baseToken,
                    UniswapV3Pool(_v3Pool).fee(),
                    totalBorrow
                );
            }
            if (_limitPrice != 0) {
                tickUpper = TickMath.getTickAtSqrtRatio(
                    uniswapV3Helper.priceToSqrtPriceX96(
                        _limitPrice,
                        isBaseToken0 ? ERC20(baseToken).decimals() : ERC20(quoteToken).decimals()
                    )
                );
                tickLower = tickUpper + 1;

                (tokenIdLiquidity, , amount0, amount1) = uniswapV3Helper.mintPosition(
                    UniswapV3Pool(_v3Pool),
                    isBaseToken0 ? amountBorrow + _amount : 0,
                    isBaseToken0 ? 0 : amountBorrow + _amount,
                    tickLower,
                    tickUpper
                );
            }
        }
        // position size calculation
        uint128 positionSize;
        if (_isShort) {
            positionSize = uint128(amountBorrow);
        } else if (_leverage != 0) {
            positionSize = uint128(_amount + amountBorrow);
        } else {
            positionSize = _amount;
        }

        openPositions[posId] = PositionParams(
            UniswapV3Pool(_v3Pool),
            ERC20(baseToken),
            ERC20(quoteToken),
            _amount,
            positionSize,
            liquidationReward,
            uint64(block.timestamp),
            _isShort,
            isBaseToken0,
            _leverage,
            totalBorrow,
            hourlyFees,
            breakEvenLimit,
            _limitPrice,
            _stopLossPrice,
            tokenIdLiquidity
        );
        ++totalNbPos;
        return safeMint(_trader);
    }

    function checkPositionParams(
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint256 _amount,
        uint256 _limitPrice,
        uint256 _stopLossPrice
    ) private view returns (uint256, address, address, bool) {
        address baseToken;
        address quoteToken;

        if (UniswapV3Pool(_v3Pool).factory() != liquidityPoolFactoryUniswapV3) {
            revert Positions__POOL_NOT_OFFICIAL(_v3Pool);
        }
        // check token
        if (
            UniswapV3Pool(_v3Pool).token0() != _token && UniswapV3Pool(_v3Pool).token1() != _token
        ) {
            revert Positions__TOKEN_NOT_SUPPORTED(_token);
        }

        /**
         * @dev The user need to open a long position by sending
         * the base token and open a short position by depositing the quote token.
         */
        if (_isShort) {
            quoteToken = _token;
            baseToken = (_token == UniswapV3Pool(_v3Pool).token0())
                ? UniswapV3Pool(_v3Pool).token1()
                : UniswapV3Pool(_v3Pool).token0();
        } else {
            baseToken = _token;
            quoteToken = (_token == UniswapV3Pool(_v3Pool).token0())
                ? UniswapV3Pool(_v3Pool).token1()
                : UniswapV3Pool(_v3Pool).token0();
        }
        bool isBaseToken0 = (baseToken == UniswapV3Pool(_v3Pool).token0());

        // check if pair is supported by PriceFeed
        if (!PriceFeedL1(priceFeed).isPairSupported(baseToken, quoteToken)) {
            revert Positions__NO_PRICE_FEED(baseToken, quoteToken);
        }

        uint256 price = PriceFeedL1(priceFeed).getPairLatestPrice(baseToken, quoteToken);

        // check leverage
        if (_leverage < 1 || _leverage > MAX_LEVERAGE) {
            revert Positions__LEVERAGE_NOT_IN_RANGE(_leverage);
        }
        // when margin position check if token is supported by a LiquidityPool
        if (_leverage != 1) {
            if (
                _isShort &&
                LiquidityPoolFactory(liquidityPoolFactory).getTokenToLiquidityPools(baseToken) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(baseToken);
            }
            if (
                !_isShort &&
                LiquidityPoolFactory(liquidityPoolFactory).getTokenToLiquidityPools(quoteToken) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(quoteToken);
            }
        }

        // check amount
        if (
            (_amount * PriceFeedL1(priceFeed).getTokenLatestPriceInUSD(_token)) /
                ERC20(_token).decimals() <
            MIN_POSITION_AMOUNT_IN_USD * ORACLE_DECIMALS_USD
        ) {
            revert Positions__AMOUNT_TO_SMALL(_amount);
        }

        if (_isShort) {
            if (_limitPrice > price) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(_limitPrice);
            }
            if (_stopLossPrice < price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(_stopLossPrice);
            }
        } else {
            if (_limitPrice < price) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(_limitPrice);
            }
            if (_stopLossPrice > price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(_stopLossPrice);
            }
        }
        return (price, baseToken, quoteToken, isBaseToken0);
    }

    function closePosition(
        address _trader,
        uint256 _posId
    ) external onlyOwner isPositionOwned(_trader, _posId) {
        _closePosition(_trader, _posId);
    }

    function liquidatePosition(
        address _liquidator,
        uint256 _posId
    ) external onlyOwner isLiquidable(_posId) {
        _closePosition(_liquidator, _posId);
    }

    /**
     * @dev Close/Liquidate a position
     * @notice the 5 states:
     *  - 1. The position crossed over the limit ordre
     *  - 2. Nothing happened => just refund the trader
     *  - 3. The position crossed over the stop loss
     *  - 4. The position is liquidable => no bad debt
     *  - 5. The position is liquidable => bad debt
     */
    function _closePosition(
        address _liquidator,
        uint256 _posId
    ) internal nonReentrant isPositionOpen(_posId) {
        address trader = ownerOf(_posId);
        PositionParams memory posParms = openPositions[_posId];
        bool isMargin = posParms.leverage != 1 || posParms.isShort;
        uint256 state = getPositionState(_posId);
        LiquidityPool liquidityPoolToUse = LiquidityPool(
            LiquidityPoolFactory(liquidityPoolFactory).getTokenToLiquidityPools(
                posParms.isShort ? address(posParms.quoteToken) : address(posParms.baseToken)
            )
        );

        uint256 amount0;
        uint256 amount1;
        // Close position
        if (posParms.limitPrice != 0) {
            (amount0, amount1) = uniswapV3Helper.burnPosition(posParms.tokenIdLiquidity);
            /* Since the liquidity position is only 1 tick wide, we can assume
             * that this will rarely revert here. */
            if (amount0 != 0 && amount1 != 0) {
                revert Positions__WAIT_FOR_LIMIT_ORDER_TO_COMPLET(_posId);
            }
        } else if (posParms.isShort) {
            posParms.isBaseToken0 ? amount0 = 0 : amount1 = posParms.positionSize;
            posParms.isBaseToken0 ? amount0 = posParms.positionSize : amount1 = 0;
        } else {
            posParms.isBaseToken0 ? amount0 = posParms.positionSize : amount1 = 0;
            posParms.isBaseToken0 ? amount0 = 0 : amount1 = posParms.positionSize;
        }
        address addTokenInitiallySupplied = posParms.isShort
            ? address(posParms.quoteToken)
            : address(posParms.baseToken);
        // will be used if margin position
        address addTokenBorrowed = posParms.isShort
            ? address(posParms.quoteToken)
            : address(posParms.baseToken);

        uint256 amountTokenReceived = amount0 != 0 ? amount0 : amount1;
        // prettier-ignore
        address addTokenReceived = (amount0 != 0)
            ? posParms.isBaseToken0
                ? address(posParms.baseToken)
                : address(posParms.quoteToken)
            : posParms.isBaseToken0
                ? address(posParms.quoteToken)
                : address(posParms.baseToken);

        uint256 interest = posParms.hourlyFees * ((block.timestamp - posParms.timestamp) / 3600);

        // These state assume that the oracle price and the uniswap price are CONCISTENT
        if (state == 1) {
            if (addTokenBorrowed != addTokenReceived) {
                revert Positions__TOKEN_RECEIVED_NOT_CONCISTENT(addTokenBorrowed, addTokenReceived);
            }
            if (isMargin) {
                // can't have loss here since the limit order is crossed
                ERC20(addTokenBorrowed).safeApprove(
                    address(liquidityPoolToUse),
                    posParms.totalBorrow + interest
                );
                liquidityPoolToUse.refund(posParms.totalBorrow, interest, 0);
                if (posParms.isShort) {
                    amountTokenReceived += posParms.collateralSize;
                }
                ERC20(addTokenBorrowed).safeTransfer(
                    trader,
                    amountTokenReceived - interest - posParms.totalBorrow
                );
            } else {
                ERC20(addTokenBorrowed).safeTransfer(trader, amountTokenReceived);
            }
        } else if (state == 2) {
            if (addTokenBorrowed == addTokenReceived) {
                revert Positions__TOKEN_RECEIVED_NOT_CONCISTENT(addTokenBorrowed, addTokenReceived);
            }
            if (isMargin) {
                if (posParms.isShort) {
                    amountTokenReceived += posParms.collateralSize;
                }
                // we need first to swap back to refund the pool
                (uint256 inAmount, uint256 outAmount) = uniswapV3Helper.swapMaxTokenPossible(
                    addTokenReceived,
                    addTokenBorrowed,
                    UniswapV3Pool(posParms.v3Pool).fee(),
                    posParms.totalBorrow + interest,
                    amountTokenReceived
                );
                // loss should not occur here but in case of, we refund the pool
                int256 lossTemp = int256(outAmount - posParms.totalBorrow - interest);
                uint256 loss = lossTemp < 0 ? uint256(-lossTemp) : uint256(0);
                ERC20(addTokenBorrowed).safeApprove(
                    address(liquidityPoolToUse),
                    posParms.totalBorrow + interest - loss
                );
                liquidityPoolToUse.refund(posParms.totalBorrow, interest, loss);
                if (loss == 0) {
                    ERC20(addTokenReceived).safeTransfer(trader, amountTokenReceived - inAmount);
                }
            } else {
                ERC20(addTokenReceived).safeTransfer(trader, amountTokenReceived);
            }
        }
        // state 3, 4 and 5
        else {
            if (addTokenBorrowed == addTokenReceived) {
                revert Positions__TOKEN_RECEIVED_NOT_CONCISTENT(addTokenBorrowed, addTokenReceived);
            }
            if (posParms.isShort) {
                amountTokenReceived += posParms.collateralSize;
            }
            uint256 outAmount = uniswapV3Helper.swapExactInputSingle(
                addTokenReceived,
                addTokenBorrowed,
                UniswapV3Pool(posParms.v3Pool).fee(),
                amountTokenReceived
            );

            if (isMargin) {
                int256 lossTemp = int256(outAmount - posParms.totalBorrow - interest);
                uint256 loss = lossTemp < 0 ? uint256(-lossTemp) : uint256(0);
                ERC20(addTokenBorrowed).safeApprove(
                    address(liquidityPoolToUse),
                    posParms.totalBorrow + interest - loss
                );
                liquidityPoolToUse.refund(posParms.totalBorrow, interest, loss);
                if (loss == 0) {
                    ERC20(addTokenBorrowed).safeTransfer(
                        trader,
                        outAmount - posParms.totalBorrow - interest
                    );
                }
            } else {
                ERC20(addTokenBorrowed).safeTransfer(trader, outAmount);
            }
        }

        --totalNbPos;
        delete openPositions[_posId];
        safeBurn(_posId);
        ERC20(addTokenInitiallySupplied).safeTransfer(_liquidator, posParms.liquidationReward);
    }

    // we can only edit the stop loss price for now
    function editPosition(
        address _trader,
        uint256 _posId,
        uint256 _newStopLossPrice
    ) external onlyOwner isPositionOwned(_trader, _posId) {
        // check params
        uint256 price = PriceFeedL1(priceFeed).getPairLatestPrice(
            address(openPositions[_posId].baseToken),
            address(openPositions[_posId].quoteToken)
        );
        if (openPositions[_posId].isShort) {
            if (_newStopLossPrice < price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(_newStopLossPrice);
            }
        } else {
            if (_newStopLossPrice > price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(_newStopLossPrice);
            }
        }
        openPositions[_posId].stopLossPrice = _newStopLossPrice;
    }

    /* @notice 5 states:
     *  - 1. The position crossed over the limit ordre
     *  - 2. Nothing happened => just refund the trader
     *  - 3. The position crossed over the stop loss
     *  - 4. The position is liquidable => no bad debt
     *  - 5. The position is liquidable => bad debt
     */
    function getPositionState(uint256 _posId) public view returns (uint256) {
        bool isShort = openPositions[_posId].isShort;
        uint256 breakEvenLimit = openPositions[_posId].breakEvenLimit;
        uint160 limitPrice = openPositions[_posId].limitPrice;
        uint256 stopLossPrice = openPositions[_posId].stopLossPrice;
        uint256 price = PriceFeedL1(priceFeed).getPairLatestPrice(
            address(openPositions[_posId].baseToken),
            address(openPositions[_posId].quoteToken)
        );
        uint256 lidTresh = isShort
            ? (breakEvenLimit * (10000 - LIQUIDATION_THRESHOLD)) / 10000
            : (breakEvenLimit * (LIQUIDATION_THRESHOLD + 10000)) / 10000;

        // closable because of take profit
        if (isShort) {
            if (price < limitPrice) return 1;
            if (price >= breakEvenLimit) return 5;
            if (price >= lidTresh) return 4;
            if (price >= stopLossPrice) return 3;
        } else {
            if (price > limitPrice) return 1;
            if (price <= breakEvenLimit) return 5;
            if (price <= lidTresh) return 4;
            if (price <= stopLossPrice) return 3;
        }
        return 2;
    }

    function getTraderPositions(address _traderAdd) external view returns (uint256[] memory) {
        uint256 nbOfPositions = balanceOf(_traderAdd);
        uint256[] memory traderPositions = new uint256[](nbOfPositions);
        // start form the highest posId and stop when the all positions are found
        uint256 posId_ = 0;
        for (uint256 i = posId; i > 0; --i) {
            if (ownerOf(i) == _traderAdd) {
                traderPositions[posId_] = i;
                if (++posId_ == nbOfPositions) {
                    break;
                }
            }
        }
        return traderPositions;
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        uint256[] memory liquidablePositions;
        // start form the highest posId and stop when the all positions are found
        uint256 posId_ = 0;
        for (uint256 i = posId; i > 0; --i) {
            if (getPositionState(i) != 2) {
                liquidablePositions[posId_] = i;
                if (++posId_ == totalNbPos) {
                    break;
                }
            }
        }
        return liquidablePositions;
    }
}
