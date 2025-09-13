// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Errors
error LiquidityPool__NOT_ENOUGH_LIQUIDITY(uint256 maxBorrowCapatity);

contract LiquidityPool is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    uint256 private borrowedFunds; // Funds currently used by positions

    uint256 private MAX_BORROW_RATIO = 8000; // in basis points => 80%

    constructor(
        IERC20 _asset,
        address _positions,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        transferOwnership(_positions);
    }

    // --------------- Leveraged Positions Zone ---------------
    // @note We don't track the debt in this contract, it's tracked in the Positions contract

    /**
     * @notice Borrow funds from the pool to open a leveraged position
     * @dev Only the owner (the Positions contract) can borrow funds
     * @param _amountToBorrow amount to borrow
     */
    function borrow(uint256 _amountToBorrow) external onlyOwner {
        uint256 borrowCapacity = borrowCapacityLeft();
        if (_amountToBorrow > borrowCapacity)
            revert LiquidityPool__NOT_ENOUGH_LIQUIDITY(borrowCapacity);
        borrowedFunds += _amountToBorrow;
        IERC20(asset()).safeTransfer(msg.sender, _amountToBorrow);
    }

    /**
     * @notice Refund funds from the pool once the position is closed
     * @dev Positions contract will need to approve the LiquidityPool to transfer funds
     * @param _amountBorrowed amount that was borrowed
     * @param _interests interest to earned with fees
     * @param _losses losses when a postion was not liquidated in time
     */
    function refund(
        uint256 _amountBorrowed,
        uint256 _interests,
        uint256 _losses
    ) external onlyOwner {
        // Losses are taken by the pool
        borrowedFunds = uint256(int256(borrowedFunds) - int256(_amountBorrowed));
        IERC20(asset()).safeTransferFrom(
            msg.sender,
            address(this),
            _amountBorrowed + _interests - _losses
        );
    }

    // --------------- View Zone ---------------

    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + borrowedFunds;
    }

    function rawTotalAsset() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function getBorrowedFund() external view returns (uint256) {
        return borrowedFunds;
    }

    function borrowCapacityLeft() public view returns (uint256) {
        return ((totalAssets() * MAX_BORROW_RATIO) / 10000) - borrowedFunds;
    }
}
