// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "./interfaces/IUniswapV3.sol";

import {PriceFeedL1} from "./PriceFeedL1.sol";
import {LiquidityPoolFactory} from "./LiquidityPoolFactory.sol";
import {UniswapV3Helper} from "./UniswapV3Helper.sol";
import {LiquidityPool} from "./LiquidityPool.sol";
import {FeeManager} from "./FeeManager.sol";
import {
    PositionParams,
    Positions__POSITION_NOT_OPEN,
    Positions__POSITION_NOT_LIQUIDABLE_YET,
    Positions__POSITION_NOT_OWNED,
    Positions__POOL_NOT_OFFICIAL,
    Positions__TOKEN_NOT_SUPPORTED,
    Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN,
    Positions__NO_PRICE_FEED,
    Positions__LEVERAGE_NOT_IN_RANGE,
    Positions__AMOUNT_TO_SMALL,
    Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT,
    Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT,
    Positions__NOT_LIQUIDABLE,
    Positions__WAIT_FOR_LIMIT_ORDER_TO_COMPLET,
    Positions__TOKEN_RECEIVED_NOT_CONCISTENT,
    PositionState
} from "./libraries/PositionTypes.sol";

import {PositionLogic} from "./libraries/PositionLogic.sol";

contract Positions is ERC721, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Variables
    uint256 public constant LIQUIDATION_THRESHOLD = 1000; // 10% of margin
    uint256 public constant MIN_POSITION_AMOUNT_IN_USD = 100e18;
    uint256 public constant MAX_LEVERAGE = 3;
    uint256 public constant USD_DECIMALS = 18; // The standard for USD values in this contract

    LiquidityPoolFactory public immutable LIQUIDITY_POOL_FACTORY;
    PriceFeedL1 public immutable PRICE_FEED;
    UniswapV3Helper public immutable UNISWAP_V3_HELPER;
    address public immutable LIQUIDITY_POOL_FACTORY_UNISWAP_V3;
    address public treasure;
    FeeManager public feeManager;

    uint256 public posId = 1;
    uint256 public totalNbPos;
    mapping(uint256 => PositionParams) public openPositions;

    constructor(
        address _priceFeed,
        address _liquidityPoolFactory,
        address _liquidityPoolFactoryUniswapV3,
        address _uniswapV3Helper,
        address _treasure,
        address _feeManager
    ) ERC721("Uniswap-MAX", "UNIMAX") Ownable(msg.sender) {
        LIQUIDITY_POOL_FACTORY_UNISWAP_V3 = _liquidityPoolFactoryUniswapV3;
        LIQUIDITY_POOL_FACTORY = LiquidityPoolFactory(_liquidityPoolFactory);
        PRICE_FEED = PriceFeedL1(_priceFeed);
        UNISWAP_V3_HELPER = UniswapV3Helper(payable(_uniswapV3Helper));
        treasure = _treasure;
        feeManager = FeeManager(_feeManager);
    }

    modifier isPositionOpen(uint256 _posId) {
        if (_ownerOf(_posId) == address(0)) {
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
        if (getPositionState(_posId) == PositionState.ACTIVE) {
            revert Positions__POSITION_NOT_LIQUIDABLE_YET(_posId);
        }
        _;
    }

    /**
     * @notice Pauses the contract in emergency situations
     * @dev Only owner can pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev Only owner can unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // --------------- ERC721 Zone ---------------

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function safeMint(address to) private returns (uint256) {
        uint256 _posId = posId;
        ++posId;
        _mint(to, _posId);
        return _posId;
    }

    function safeBurn(uint256 _posId) private {
        _burn(_posId);
    }

    // --------------- Trader Zone ---------------
    /**
     * @notice function to open a new positions
     * @param _trader trader address
     * @param _token0 token sent
     * @param _token1 token traded
     * @param _fee Uniswap V3 pool fee
     * @param _isShort true if short else long
     * @param _leverage leverage value 1 -> 5
     * @param _amount trade amount in token0
     * @param _limitPrice limit price in token1
     * @param _stopLossPrice stop loss price in token1
     * @return posId position Id
     */
    function openPosition(
        address _trader,
        address _token0,
        address _token1,
        uint24 _fee,
        bool _isShort,
        uint8 _leverage,
        uint128 _amount,
        uint160 _limitPrice,
        uint256 _stopLossPrice
    ) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        // Check params
        // Check params
        PositionLogic.ValidationResult memory validationResult = PositionLogic.validateOpenPosition(
            PositionLogic.ValidationParams({
                token0: _token0,
                token1: _token1,
                fee: _fee,
                isShort: _isShort,
                leverage: _leverage,
                amount: _amount,
                limitPrice: _limitPrice,
                stopLossPrice: _stopLossPrice,
                liquidityPoolFactoryUniswapV3: LIQUIDITY_POOL_FACTORY_UNISWAP_V3,
                liquidityPoolFactory: address(LIQUIDITY_POOL_FACTORY),
                priceFeed: address(PRICE_FEED),
                maxLeverage: MAX_LEVERAGE,
                minPositionAmountInUsd: MIN_POSITION_AMOUNT_IN_USD
            })
        );

        address baseToken = validationResult.baseToken;
        address quoteToken = validationResult.quoteToken;
        uint256 price = validationResult.price;
        address v3Pool = validationResult.v3Pool;
        bool isBaseToken0 = validationResult.isBaseToken0;

        bool isMargin = _leverage != 1 || _isShort;

        // transfer funds to the contract (trader need to approve first)
        IERC20(_token0).safeTransferFrom(_trader, address(this), _amount);

        // Compute parameters
        uint256 breakEvenLimit;
        uint256 totalBorrow;
        uint256 tokenIdLiquidity;
        uint256 amountBorrow;

        (uint256 treasureFee, uint256 liquidationRewardRate) = feeManager.getFees(_trader);

        // take opening fees
        uint128 liquidationReward = uint128((_amount * liquidationRewardRate) / 10000);
        _amount = _amount - liquidationReward;

        uint256 treasureAmount = (_amount * treasureFee) / 10000;
        IERC20(_token0).safeTransfer(treasure, treasureAmount);
        _amount = _amount - uint128(treasureAmount);

        if (isMargin) {
            if (_isShort) {
                // breakEven = price + price/leverage (short becomes underwater when price rises)
                breakEvenLimit = price + (price * 10000) / (uint256(_leverage) * 10000);
                totalBorrow =
                    (_amount * (10 ** IERC20Metadata(baseToken).decimals()) * _leverage) /
                    price; // Borrow baseToken
            } else {
                // breakEven = price - price/leverage (long becomes underwater when price drops)
                breakEvenLimit = price - (price * 10000) / (uint256(_leverage) * 10000);
                totalBorrow =
                    (_amount * (_leverage - 1) * price) /
                    (10 ** IERC20Metadata(baseToken).decimals()); // Borrow quoteToken
            }

            address cacheLiquidityPoolToUse = LiquidityPoolFactory(LIQUIDITY_POOL_FACTORY)
                .getTokenToLiquidityPools(_isShort ? baseToken : quoteToken);

            // Borrow funds from the pool
            LiquidityPool(cacheLiquidityPoolToUse).borrow(totalBorrow);

            if (_isShort) {
                SafeERC20.forceApprove(IERC20(baseToken), address(UNISWAP_V3_HELPER), totalBorrow);

                uint256 priceBaseToQuote = PRICE_FEED.getPairLatestPrice(baseToken, quoteToken);
                uint256 minOut = (totalBorrow * priceBaseToQuote) /
                    (10 ** IERC20Metadata(baseToken).decimals());
                minOut = (minOut * 9500) / 10000;

                amountBorrow = UNISWAP_V3_HELPER.swapExactInputSingle(
                    baseToken,
                    quoteToken,
                    IUniswapV3Pool(v3Pool).fee(),
                    totalBorrow,
                    minOut
                );
            } else {
                if (_leverage != 1) {
                    SafeERC20.forceApprove(
                        IERC20(quoteToken),
                        address(UNISWAP_V3_HELPER),
                        totalBorrow
                    );

                    uint256 priceQuoteToBase = PRICE_FEED.getPairLatestPrice(quoteToken, baseToken);
                    uint256 minOut = (totalBorrow * priceQuoteToBase) /
                        (10 ** IERC20Metadata(quoteToken).decimals());
                    minOut = (minOut * 9500) / 10000;

                    amountBorrow = UNISWAP_V3_HELPER.swapExactInputSingle(
                        quoteToken,
                        baseToken,
                        IUniswapV3Pool(v3Pool).fee(),
                        totalBorrow,
                        minOut
                    );
                }
            }
        } else {
            // if not margin
            if (_limitPrice != 0) {
                revert("Limit orders for non-margin trades are temporarily disabled");
            }
        }

        // position size calculation
        uint128 positionSize;
        if (_isShort) {
            positionSize = uint128(amountBorrow);
        } else if (_leverage != 1) {
            positionSize = uint128(_amount + amountBorrow);
        } else {
            positionSize = _amount;
        }

        openPositions[posId] = PositionParams(
            v3Pool,
            IERC20(baseToken),
            IERC20(quoteToken),
            _amount,
            positionSize,
            price,
            liquidationReward,
            uint64(block.timestamp),
            uint64(block.number),
            _isShort,
            isBaseToken0,
            _leverage,
            totalBorrow,
            breakEvenLimit,
            _limitPrice,
            _stopLossPrice,
            tokenIdLiquidity
        );
        ++totalNbPos;
        return safeMint(_trader);
    }

    /**
     * @notice function to close a position can only be call by the position owner
     * @param _trader trader address
     * @param _posId position Id
     */
    function closePosition(
        address _trader,
        uint256 _posId
    ) external onlyOwner isPositionOwned(_trader, _posId) nonReentrant whenNotPaused {
        _closePosition(_trader, _posId);
    }

    /**
     * @notice function to liquidate a position canbe call be every one
     * @param _liquidator liquidator address
     * @param _posId position Id
     */
    function liquidatePosition(
        address _liquidator,
        uint256 _posId
    ) external onlyOwner isLiquidable(_posId) nonReentrant whenNotPaused {
        _closePosition(_liquidator, _posId);
    }

    /**
     * @dev Close/Liquidate a position
     * @notice the 5 states:
     * - 1. The position crossed over the limit ordre
     * - 2. Nothing happened => just refund the trader
     * - 3. The position crossed over the stop loss
     * - 4. Liquidation threshold => no bad debt
     * - 5. Protocol loss => bad debt
     * - 6. The position is liquidable by time limit
     */
    function _closePosition(
        address _liquidator,
        uint256 _posId
    ) internal isPositionOpen(_posId) {
        address trader = ownerOf(_posId);
        PositionParams memory posParms = openPositions[_posId];
        bool isMargin = posParms.leverage != 1 || posParms.isShort;
        PositionState state = getPositionState(_posId);
        LiquidityPool liquidityPoolToUse = LiquidityPool(
            LiquidityPoolFactory(LIQUIDITY_POOL_FACTORY).getTokenToLiquidityPools(
                posParms.isShort ? address(posParms.baseToken) : address(posParms.quoteToken)
            )
        );

        (uint256 treasureFee, ) = feeManager.getFees(trader);

        uint256 amount0;
        uint256 amount1;
        address addTokenReceived;
        address addTokenInitiallySupplied;
        address addTokenBorrowed;
        // Close position
        if (posParms.isShort) {
            posParms.isBaseToken0
                ? amount1 = posParms.positionSize
                : amount0 = posParms.positionSize;
        } else {
            posParms.isBaseToken0
                ? amount0 = posParms.positionSize
                : amount1 = posParms.positionSize;
        }

        // prettier-ignore
        addTokenReceived = (amount0 != 0)
            ? posParms.isBaseToken0
                ? address(posParms.baseToken)
                : address(posParms.quoteToken)
            : posParms.isBaseToken0
                ? address(posParms.quoteToken)
                : address(posParms.baseToken);

        addTokenInitiallySupplied = posParms.isShort
            ? address(posParms.quoteToken)
            : address(posParms.baseToken);
        // will be used if margin position
        addTokenBorrowed = posParms.isShort
            ? address(posParms.baseToken)
            : address(posParms.quoteToken);

        uint256 amountTokenReceived = amount0 != 0 ? amount0 : amount1;

        address tokenToTrader = addTokenReceived == address(posParms.baseToken)
            ? address(posParms.quoteToken)
            : address(posParms.baseToken);

        // These state assume that the oracle price and the uniswap price are CONCISTENT
        // state 1+classic
        if (state == PositionState.TAKE_PROFIT && !isMargin) {
            if (addTokenBorrowed != addTokenReceived) {
                revert Positions__TOKEN_RECEIVED_NOT_CONCISTENT(
                    addTokenBorrowed,
                    addTokenReceived,
                    1
                );
            }
            IERC20(addTokenBorrowed).safeTransfer(trader, amountTokenReceived);
        }
        // state 1+margin, 2, 3, 4 and 5
        else {
            if (addTokenBorrowed == addTokenReceived) {
                revert Positions__TOKEN_RECEIVED_NOT_CONCISTENT(
                    addTokenBorrowed,
                    addTokenReceived,
                    2345
                );
            }

            if (isMargin) {
                // when margin we need to swap back to refund the pool
                // but when refund the trader with the token received
                if (posParms.isShort) {
                    amountTokenReceived += posParms.collateralSize;
                }
                // we need first to swap back to refund the pool
                (uint256 inAmount, uint256 outAmount) = swapMaxTokenPossible(
                    addTokenReceived,
                    tokenToTrader,
                    IUniswapV3Pool(posParms.v3Pool).fee(),
                    posParms.totalBorrow,
                    amountTokenReceived
                );
                // loss should not occur here but in case of, we refund the pool
                int256 remaining = int256(int(outAmount) - int(posParms.totalBorrow));
                uint256 loss = remaining < 0 ? uint256(-remaining) : uint256(0);
                SafeERC20.forceApprove(
                    IERC20(addTokenBorrowed),
                    address(liquidityPoolToUse),
                    posParms.totalBorrow - loss
                );
                liquidityPoolToUse.refund(posParms.totalBorrow, 0, loss);
                if (loss == 0) {
                    uint256 treasureAmount = ((amountTokenReceived - inAmount) * treasureFee) /
                        10000;
                    IERC20(addTokenReceived).safeTransfer(treasure, treasureAmount);
                    IERC20(addTokenReceived).safeTransfer(
                        trader,
                        amountTokenReceived - inAmount - treasureAmount
                    );
                }
            } else if (state == PositionState.ACTIVE) {
                uint256 treasureAmount = (amountTokenReceived * treasureFee) / 10000;
                IERC20(addTokenReceived).safeTransfer(treasure, treasureAmount);
                IERC20(addTokenReceived).safeTransfer(trader, amountTokenReceived - treasureAmount);
            } else {
                // when not margin, we need to swap to the other token
                SafeERC20.forceApprove(
                    IERC20(addTokenReceived),
                    address(UNISWAP_V3_HELPER),
                    amountTokenReceived
                );

                uint256 price = PRICE_FEED.getPairLatestPrice(addTokenReceived, tokenToTrader);
                uint256 minOut = (amountTokenReceived * price) /
                    (10 ** IERC20Metadata(addTokenReceived).decimals());
                minOut = (minOut * 9500) / 10000;

                uint256 outAmount = UNISWAP_V3_HELPER.swapExactInputSingle(
                    addTokenReceived,
                    tokenToTrader,
                    IUniswapV3Pool(posParms.v3Pool).fee(),
                    amountTokenReceived,
                    minOut
                );
                uint256 treasureAmount = (outAmount * treasureFee) / 10000;
                IERC20(tokenToTrader).safeTransfer(treasure, treasureAmount);
                IERC20(tokenToTrader).safeTransfer(trader, outAmount - treasureAmount);
            }
        }

        --totalNbPos;
        delete openPositions[_posId];
        safeBurn(_posId);
        IERC20(addTokenInitiallySupplied).safeTransfer(_liquidator, posParms.liquidationReward);
    }

    /**
     * @notice function to edit a position. We can only edit the stop loss price for now.
     * @param _trader trader address
     * @param _posId position Id
     * @param _newStopLossPrice new SL
     */
    function editPosition(
        address _trader,
        uint256 _posId,
        uint256 _newStopLossPrice
    ) external onlyOwner isPositionOwned(_trader, _posId) nonReentrant whenNotPaused {
        // check params
        uint256 price = PRICE_FEED.getPairLatestPrice(
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

    /**
     * @notice 5 states:
     * - 1. The position crossed over the limit ordre
     * - 2. Nothing happened => just refund the trader
     * - 3. The position crossed over the stop loss
     * - 4. The position is liquidable => no bad debt
     * - 5. The position is liquidable => bad debt
     * - 6. The position is liquidable by time limit
     * @param _posId position Id
     */
    function getPositionState(uint256 _posId) public view returns (PositionState) {
        if (_ownerOf(_posId) == address(0)) {
            return PositionState.NONE;
        }
        bool isShort = openPositions[_posId].isShort;
        uint256 breakEvenLimit = openPositions[_posId].breakEvenLimit;
        uint160 limitPrice = openPositions[_posId].limitPrice;
        uint256 stopLossPrice = openPositions[_posId].stopLossPrice;
        uint256 price = PRICE_FEED.getPairLatestPrice(
            address(openPositions[_posId].baseToken),
            address(openPositions[_posId].quoteToken)
        );
        uint256 lidTresh = isShort
            ? (breakEvenLimit * (10000 - LIQUIDATION_THRESHOLD)) / 10000
            : (breakEvenLimit * (LIQUIDATION_THRESHOLD + 10000)) / 10000;

        // closable because of take profit
        if (isShort) {
            if (limitPrice != 0 && price < limitPrice) return PositionState.TAKE_PROFIT;
            if (breakEvenLimit != 0 && price >= breakEvenLimit) return PositionState.BAD_DEBT;
            if (lidTresh != 0 && price >= lidTresh) return PositionState.LIQUIDATABLE;
            if (stopLossPrice != 0 && price >= stopLossPrice) return PositionState.STOP_LOSS;
        } else {
            if (limitPrice != 0 && price > limitPrice) return PositionState.TAKE_PROFIT;
            if (breakEvenLimit != 0 && price <= breakEvenLimit) return PositionState.BAD_DEBT;
            if (lidTresh != 0 && price <= lidTresh) return PositionState.LIQUIDATABLE;
            if (stopLossPrice != 0 && price <= stopLossPrice) return PositionState.STOP_LOSS;
        }

        // Check both timestamp-based and block-based expiration for manipulation resistance
        // [MED-002] Using block numbers prevents timestamp manipulation by miners
        address positionOwner = _ownerOf(_posId);
        uint256 timeBasedExpiry = feeManager.getPositionLifeTime(positionOwner);
        uint256 blockBasedExpiry = feeManager.getPositionLifeBlocks(positionOwner);
        
        bool timeExpired = block.timestamp - openPositions[_posId].timestamp > timeBasedExpiry;
        bool blocksExpired = block.number - openPositions[_posId].blockNumber > blockBasedExpiry;
        
        // Position expires if BOTH time AND blocks have passed (prevents manipulation)
        if (timeExpired && blocksExpired) {
            return PositionState.EXPIRED;
        }
        return PositionState.ACTIVE;
    }

    function getPositionParams(
        uint256 _posId
    )
        external
        view
        returns (
            address baseToken_,
            address quoteToken_,
            uint128 positionSize_,
            uint64 timestamp_,
            bool isShort_,
            uint8 leverage_,
            uint256 breakEvenLimit_,
            uint160 limitPrice_,
            uint256 stopLossPrice_,
            int128 currentPnL_,
            int128 collateralLeft_
        )
    {
        baseToken_ = address(openPositions[_posId].baseToken);
        quoteToken_ = address(openPositions[_posId].quoteToken);
        positionSize_ = openPositions[_posId].positionSize;
        timestamp_ = openPositions[_posId].timestamp;
        isShort_ = openPositions[_posId].isShort;
        leverage_ = openPositions[_posId].leverage;
        breakEvenLimit_ = openPositions[_posId].breakEvenLimit;
        limitPrice_ = openPositions[_posId].limitPrice;
        stopLossPrice_ = openPositions[_posId].stopLossPrice;

        uint256 initialPrice = openPositions[_posId].initialPrice;
        uint256 currentPrice = PRICE_FEED.getPairLatestPrice(baseToken_, quoteToken_);

        int256 share = 10000 - int(currentPrice * 10000) / int(initialPrice);

        currentPnL_ = int128((int128(positionSize_) * share) / 10000);

        currentPnL_ = isShort_ ? currentPnL_ : -currentPnL_;

        currentPnL_ = currentPnL_ - int128(openPositions[_posId].liquidationReward);

        collateralLeft_ = int128(openPositions[_posId].collateralSize) + currentPnL_;
    }

    function swapMaxTokenPossible(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 amountOut,
        uint256 amountInMaximum
    ) private returns (uint256, uint256) {
        SafeERC20.forceApprove(IERC20(_token0), address(UNISWAP_V3_HELPER), amountInMaximum);
        uint256 swapCost = UNISWAP_V3_HELPER.swapExactOutputSingle(
            _token0,
            _token1,
            _fee,
            amountOut,
            amountInMaximum
        );
        // if swap cannot be done with amountInMaximum
        if (swapCost == 0) {
            SafeERC20.forceApprove(IERC20(_token0), address(UNISWAP_V3_HELPER), amountInMaximum);

            uint256 price = PRICE_FEED.getPairLatestPrice(_token0, _token1);
            uint256 minOut = (amountInMaximum * price) / (10 ** IERC20Metadata(_token0).decimals());
            minOut = (minOut * 9500) / 10000;

            uint256 out = UNISWAP_V3_HELPER.swapExactInputSingle(
                _token0,
                _token1,
                _fee,
                amountInMaximum,
                minOut
            );
            return (amountInMaximum, out);
        } else {
            return (swapCost, amountOut);
        }
    }

    function getTraderPositions(address _traderAdd) external view returns (uint256[] memory) {
        uint256 nbOfPositions = balanceOf(_traderAdd);
        uint256[] memory traderPositions = new uint[](nbOfPositions);
        // start form the highest posId and stop when the all positions are found
        uint256 posId_;
        for (uint256 i = posId - 1; i > 0; --i) {
            if (_ownerOf(i) == _traderAdd) {
                traderPositions[posId_] = i;
                if (++posId_ == nbOfPositions) {
                    break;
                }
            }
        }
        return traderPositions;
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        uint256[] memory liquidablePositions = new uint[](totalNbPos);
        // start form the highest posId and stop when the all positions are found
        uint256 posId_;
        for (uint256 i = posId - 1; i > 0; --i) {
            PositionState state = getPositionState(i);
            if (state != PositionState.ACTIVE && state != PositionState.NONE) {
                liquidablePositions[posId_] = i;
                if (++posId_ == totalNbPos) {
                    break;
                }
            }
        }
        return liquidablePositions;
    }
}
