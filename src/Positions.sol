// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@solmate/tokens/ERC20.sol";
import "@solmate/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@uniswapCore/contracts/libraries/TickMath.sol";
import "@uniswapCore/contracts/UniswapV3Pool.sol";
import "./PriceFeedL1.sol";
import "./LiquidityPoolFactory.sol";

import {UniswapV3Helper} from "./UniswapV3Helper.sol";

contract Positions is ERC721, Ownable {
    using FixedPointMathLib for uint256;

    // Structs
    struct PositionParams {
        UniswapV3Pool v3Pool; // pool to trade
        ERC20 baseToken; // token to trade => should be token0 or token1 of v3Pool
        ERC20 quoteToken; // token to trade => should be the other token of v3Pool
        uint256 initialPrice; // price of the token when the position was opened
        uint128 amount; // amount of token to trade
        uint64 timestamp; // timestamp of position creation
        bool isShort; // true if short, false if long
        uint8 leverage; // leverage of position => 0 if no leverage
        uint256 totalBorrow; // Total borrow in baseToken if long or quoteToken if short
        uint256 hourlyFees; // fees to pay every hour on the borrowed amount => 0 if no leverage
        uint256 breakEvenLimit; // After this limit the position is undercollateralize => 0 if no leverage or short
        uint160 limitPrice; // limit order price => 0 if no limit order
        uint256 stopLossPrice; // stop loss price => 0 if no stop loss
        uint256 tokenIdLiquidity; // tokenId of the liquidity position NFT => 0 if no liquidity position
    }

    // Variables
    uint256 public constant LIQUIDATION_THRESHOLD = 1000; // 10% of margin
    uint256 public constant MIN_POSITION_AMOUNT_IN_USD = 100; // To avoid DOS attack
    uint256 public constant MAX_LEVERAGE = 5;
    uint256 public constant BORROW_FEE = 20; // 0.2% when opening a position
    uint256 public constant BORROW_FEE_EVERY_HOURS = 1; // 0.01% : assets borrowed/total assets in pool * 0.01%
    uint256 public constant ORACLE_DECIMALS = 10 ** 8; // Chainlink decimals for USD

    LiquidityPoolFactory public immutable liquidityPoolFactory;
    PriceFeedL1 public immutable priceFeed;
    UniswapV3Helper public immutable uniswapV3Helper;
    address public immutable liquidityPoolFactoryUniswapV3;

    uint256 public posId;
    mapping(uint256 => PositionParams) public openPositions;

    string private constant BASE_SVG =
        "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='black' /><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    // Errors
    error Positions__POSITION_NOT_OPEN(uint256 _posId);
    error Positions__POSITION_NOT_OWNED(address _trader, uint256 _posId);
    error Positions__POOL_NOT_OFFICIAL(address _v3Pool);
    error Positions__TOKEN_NOT_SUPPORTED(address _token);
    error Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(address _token);
    error Positions__NO_PRICE_FEED(address _token0, address _token1);
    error Positions__LEVERAGE_NOT_IN_RANGE(uint8 _leverage);
    error Positions__AMOUNT_TO_SMALL(uint256 _amount);
    error Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(
        uint256 _limitPrice,
        uint256 _amount
    );
    error Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(
        uint256 _stopLossPrice,
        uint256 _amount
    );
    error Positions__NOT_LIQUIDABLE(uint256 _posId);

    constructor(
        address _market,
        address _priceFeed,
        address _liquidityPoolFactory,
        address _liquidityPoolFactoryUniswapV3,
        address _uniswapV3Helper
    ) ERC721("Uniswap-MAX", "UNIMAX") {
        transferOwnership(_market);
        liquidityPoolFactoryUniswapV3 = _liquidityPoolFactoryUniswapV3;
        liquidityPoolFactory = LiquidityPoolFactory(_liquidityPoolFactory);
        priceFeed = PriceFeedL1(_priceFeed);
        uniswapV3Helper = UniswapV3Helper(_uniswapV3Helper);
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
        uint256 _tokenId
    )
        public
        view
        virtual
        override
        isPositionOpen(_tokenId)
        returns (string memory)
    {
        string memory json = Base64.encode(
            bytes(
                string.concat(
                    tokenURIIntro(_tokenId),
                    tokenURIAttributes(openPositions[_tokenId])
                )
            )
        );

        return string.concat("data:application/json;base64,", json);
    }

    function tokenURIIntro(
        uint256 _tokenId
    ) private pure returns (string memory) {
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
                Strings.toString(_position.amount),
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

        return
            string.concat(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg))
            );
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

        // transfer funds to the contract (trader need to approve first)
        ERC20(_token).transferFrom(_trader, address(this), _amount);

        // Compute parameters
        uint256 breakEvenLimit;
        uint256 totalBorrow;
        uint256 hourlyFees;

        if (_isShort) {
            breakEvenLimit = price + (price * (10000 / _leverage)) / 10000;
            totalBorrow =
                ((_amount * ERC20(quoteToken).decimals()) / price) *
                _leverage; // Borrow baseToken
        } else {
            breakEvenLimit = price - (price * (10000 / _leverage)) / 10000;
            totalBorrow =
                (_amount * (_leverage - 1) * price) /
                (10 ** ERC20(baseToken).decimals()); // Borrow quoteToken
        }

        if (_isShort || _leverage != 1) {
            address cacheLiquidityPoolToUse = LiquidityPoolFactory(
                liquidityPoolFactory
            ).getTokenToLiquidityPools(_isShort ? quoteToken : baseToken);

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
        }

        int24 _tickUpper = TickMath.getTickAtSqrtRatio(
            uniswapV3Helper.priceToSqrtPriceX96(_limitPrice, 1)
        ); // todo convert price to sqrt ratiow
        int24 _tickLower = _tickUpper + 1;

        // do the trade on Uniswap
        uint256 tokenIdLiquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 amountOut;

        if (_isShort) {
            amountOut = uniswapV3Helper.swapExactInputSingle(
                baseToken,
                quoteToken,
                UniswapV3Pool(_v3Pool).fee(),
                totalBorrow
            );

            if (_limitPrice != 0) {
                (tokenIdLiquidity, , amount0, amount1) = uniswapV3Helper
                    .mintPosition(
                        UniswapV3Pool(_v3Pool),
                        isBaseToken0 ? 0 : amountOut,
                        isBaseToken0 ? amountOut : 0,
                        _tickLower,
                        _tickUpper
                    );
            }
        } else {
            if (_leverage != 0) {
                amountOut = uniswapV3Helper.swapExactInputSingle(
                    quoteToken,
                    baseToken,
                    UniswapV3Pool(_v3Pool).fee(),
                    totalBorrow
                );
            }
            if (_limitPrice != 0) {
                (tokenIdLiquidity, , amount0, amount1) = uniswapV3Helper
                    .mintPosition(
                        UniswapV3Pool(_v3Pool),
                        isBaseToken0 ? amountOut + _amount : 0,
                        isBaseToken0 ? 0 : amountOut + _amount,
                        _tickLower,
                        _tickUpper
                    );
            }
        }

        openPositions[posId] = PositionParams(
            UniswapV3Pool(_v3Pool),
            ERC20(baseToken),
            ERC20(quoteToken),
            price,
            _amount,
            uint64(block.timestamp),
            _isShort,
            _leverage,
            totalBorrow,
            hourlyFees,
            breakEvenLimit,
            _limitPrice,
            _stopLossPrice,
            tokenIdLiquidity
        );
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
            UniswapV3Pool(_v3Pool).token0() != _token &&
            UniswapV3Pool(_v3Pool).token1() != _token
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

        uint256 price = PriceFeedL1(priceFeed).getPairLatestPrice(
            baseToken,
            quoteToken
        );

        // check leverage
        if (_leverage < 1 || _leverage > MAX_LEVERAGE) {
            revert Positions__LEVERAGE_NOT_IN_RANGE(_leverage);
        }
        // when margin position check if token is supported by a LiquidityPool
        if (_leverage != 1) {
            if (
                _isShort &&
                LiquidityPoolFactory(liquidityPoolFactory)
                    .getTokenToLiquidityPools(baseToken) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(baseToken);
            }
            if (
                !_isShort &&
                LiquidityPoolFactory(liquidityPoolFactory)
                    .getTokenToLiquidityPools(quoteToken) ==
                address(0)
            ) {
                revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(quoteToken);
            }
        }

        // check amount
        if (
            (_amount *
                PriceFeedL1(priceFeed).getTokenLatestPriceInUSD(_token)) /
                ERC20(_token).decimals() <
            MIN_POSITION_AMOUNT_IN_USD * ORACLE_DECIMALS
        ) {
            revert Positions__AMOUNT_TO_SMALL(_amount);
        }

        if (_isShort) {
            if (_limitPrice > price) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(
                    _limitPrice,
                    _amount
                );
            }
            if (_stopLossPrice < price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(
                    _stopLossPrice,
                    _amount
                );
            }
        } else {
            if (_limitPrice < price) {
                revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(
                    _limitPrice,
                    _amount
                );
            }
            if (_stopLossPrice > price) {
                revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(
                    _stopLossPrice,
                    _amount
                );
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

    function _closePosition(address _trader, uint256 _posId) internal {
        PositionParams memory posParms = openPositions[_posId];

        // TODO check the position state

        // // Close position
        // if (posParms.limitPrice != 0) {
        //     (uint256 amount0, uint256 amount1) = posParms.v3Pool.burn(
        //         posParms.tickLower,
        //         posParms.tickUpper,
        //         posParms.amount + uint128(posParms.totalBorrow)
        //     );

        //     if (
        //         address(posParms.quoteToken) == posParms.v3Pool.token1() &&
        //         amount0 != 0
        //     ) {
        //         posParms.v3Pool.swap(
        //             address(this),
        //             false,
        //             int256(amount0),
        //             0, //TODO define slippage here
        //             abi.encode()
        //         );
        //     }

        //     if (
        //         address(posParms.quoteToken) == posParms.v3Pool.token0() &&
        //         amount1 != 0
        //     ) {
        //         posParms.v3Pool.swap(
        //             address(this),
        //             true,
        //             int256(amount1),
        //             0, //TODO define slippage here
        //             abi.encode()
        //         );
        //     }
        // }
        // if (posParms.isShort || posParms.leverage != 1) {
        //     // TODO what if there is a loss ?

        //     // pay back the loan

        //     address liquidityPool = LiquidityPoolFactory(liquidityPoolFactory)
        //         .getTokenToLiquidityPools(
        //             address(
        //                 posParms.isShort
        //                     ? posParms.baseToken
        //                     : posParms.quoteToken
        //             )
        //         );

        //     LiquidityPool(liquidityPool).refund(
        //         posParms.totalBorrow,
        //         ((block.timestamp - posParms.timestamp) / (60 * 60)) *
        //             posParms.hourlyFees +
        //             (posParms.totalBorrow * BORROW_FEE) /
        //             10000,
        //         0 // TODO compute loss
        //     );
        // }

        // // TODO what if there is a loss ?
        // posParms.baseToken.transfer(_trader, posParms.amount);

        // refund LiquidityPool + Fees

        safeBurn(_posId);
        delete openPositions[_posId];
    }

    function getTraderPositions(
        address _traderAdd
    ) external view returns (uint256[] memory) {
        uint256[] memory _traderPositions = new uint256[](
            balanceOf(_traderAdd)
        );
        uint256 _posId = 0;

        for (uint256 i = 0; i < posId; ) {
            if (ownerOf(i) == _traderAdd) {
                _traderPositions[_posId] = i;

                unchecked {
                    ++_posId;
                }
            }

            unchecked {
                ++i;
            }
        }

        return _traderPositions;
    }

    function editPosition(
        address _trader,
        uint256 _posId,
        uint160 _newLimitPrice,
        uint256 _newLstopLossPrice
    ) external onlyOwner isPositionOwned(_trader, _posId) {
        PositionParams memory posParms = openPositions[_posId];
        checkPositionParams(
            address(posParms.v3Pool),
            address(posParms.baseToken),
            posParms.isShort,
            posParms.leverage,
            posParms.amount,
            _newLimitPrice,
            _newLstopLossPrice
        );
        openPositions[_posId].limitPrice = _newLimitPrice;
        openPositions[_posId].stopLossPrice = _newLstopLossPrice;
    }

    // --------------- Liquidator Zone ---------------

    function liquidatePosition(
        address _liquidator,
        uint256 _posId
    ) external onlyOwner isPositionOpen(_posId) {
        if (!isLiquidable(_posId)) {
            revert Positions__NOT_LIQUIDABLE(_posId);
        }

        _closePosition(ownerOf(_posId), _posId);

        // TODO send reward to liquidator
        PositionParams memory posParms = openPositions[_posId];
        uint256 _price = PriceFeedL1(priceFeed).getPairLatestPrice(
            address(posParms.baseToken),
            address(posParms.quoteToken)
        );

        uint256 _breakEventPrice = (posParms.breakEvenLimit ** 2) / (2 ** 192);

        uint256 _reward;
        if (posParms.isShort) {
            if (_price > _breakEventPrice) {
                _reward = 0; // TODO define reward in the case of a loss for the protocol
            } else {
                _reward = (_breakEventPrice / _price) * posParms.amount;
            }
        } else {
            if (_price < _breakEventPrice) {
                _reward = 0; // TODO define reward in the case of a loss for the protocol
            } else {
                _reward = (_breakEventPrice / _price) * posParms.amount;
            }
        }

        posParms.quoteToken.transfer(_liquidator, _reward);

        if (_reward < posParms.amount) {
            posParms.quoteToken.transfer(
                ownerOf(_posId),
                posParms.amount - _reward
            );
        }
    }

    function isLiquidable(uint256 _posId) public view returns (bool) {
        PositionParams memory posParms = openPositions[_posId];
        uint256 _price = PriceFeedL1(priceFeed).getPairLatestPrice(
            address(posParms.baseToken),
            address(posParms.quoteToken)
        );

        // liquidable because of stop loss
        uint256 _thresholdStopLoss = (posParms.stopLossPrice *
            LIQUIDATION_THRESHOLD) / 10000;
        if (posParms.isShort) {
            if (_price > posParms.stopLossPrice + _thresholdStopLoss) {
                return true;
            }
        } else {
            if (_price < posParms.stopLossPrice - _thresholdStopLoss) {
                return true;
            }
        }

        // liquidable because of take profit
        if (posParms.isShort) {
            if (_price < posParms.limitPrice) {
                return true;
            }
        } else {
            if (_price > posParms.limitPrice) {
                return true;
            }
        }

        return false;
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        uint256[] memory _liquidablePositions = new uint256[](posId);
        uint256 _posId = 0;
        for (uint256 i = 0; i < posId; ) {
            if (isLiquidable(i)) {
                _liquidablePositions[_posId] = i;

                unchecked {
                    ++_posId;
                }
            }

            unchecked {
                ++i;
            }
        }

        assembly ("memory-safe") {
            let tosub := sub(sload(posId.slot), _posId)
            mstore(
                _liquidablePositions,
                sub(mload(_liquidablePositions), tosub)
            )
        }

        return _liquidablePositions;
    }
}
