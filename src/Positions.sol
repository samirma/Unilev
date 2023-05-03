// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswapV3/contracts/interfaces/IUniswapV3Pool.sol";

contract Positions is ERC721, Ownable {
    uint256 public posId;

    enum PositionStatus {
        OPEN,
        CLOSED,
        LIQUIDATED
    }

    struct PositionParams {
        IUniswapV3Pool v3Pool; // pool to trade
        IERC20 token; // token to trade => should be token0 or token1 of v3Pool
        uint256 value; // amount of token to trade
        bool isShort; // true if short, false if long
        uint8 leverage; // leverage of position => 0 if no leverage
        uint256 limitPrice; // limit order price => 0 if no limit order
        uint256 stopLossPrice; // stop loss price => 0 if no stop loss
        PositionStatus status; // status of position
    }

    constructor(address _market) ERC721("Uniswap-MAX", "UNIMAX") {
        transferOwnership(_market);
    }

    function safeMint(address to) private {
        uint256 _posId = posId;
        ++posId;
        _safeMint(to, _posId);
    }

    function safeBurn(uint256 _posId) private {
        _burn(_posId);
    }
}
