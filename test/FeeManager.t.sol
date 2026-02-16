// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {FeeManager} from "../src/FeeManager.sol";

contract FeeManagerTest is Test {
    FeeManager public feeManager;
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    function setUp() public {
        vm.prank(owner);
        // Default: 0.05% treasure fee, 0.03% liquidation reward
        feeManager = new FeeManager(5, 3);
    }

    function test_InitialState() public view {
        assertEq(feeManager.defaultTreasureFee(), 5);
        assertEq(feeManager.defaultLiquidationReward(), 3);
        assertEq(feeManager.owner(), owner);
    }

    function test_SetDefaultFees() public {
        vm.prank(owner);
        feeManager.setDefaultFees(10, 6);

        assertEq(feeManager.defaultTreasureFee(), 10);
        assertEq(feeManager.defaultLiquidationReward(), 6);

        // Check if getFees returns new defaults for non-custom users
        (uint256 fee, uint256 reward) = feeManager.getFees(alice);
        assertEq(fee, 10);
        assertEq(reward, 6);
    }

    function test_SetCustomFees() public {
        vm.prank(owner);
        feeManager.setCustomFees(alice, 1, 0);

        (uint256 fee, uint256 reward) = feeManager.getFees(alice);
        assertEq(fee, 1);
        assertEq(reward, 0);

        // Bob should still see defaults
        (uint256 feeBob, uint256 rewardBob) = feeManager.getFees(bob);
        assertEq(feeBob, 5);
        assertEq(rewardBob, 3);
    }

    function test_RemoveCustomFees() public {
        vm.prank(owner);
        feeManager.setCustomFees(alice, 1, 0);

        vm.prank(owner);
        feeManager.removeCustomFees(alice);

        (uint256 fee, uint256 reward) = feeManager.getFees(alice);
        assertEq(fee, 5); // Back to default
        assertEq(reward, 3);
    }

    function test_AccessControl() public {
        vm.prank(alice);
        // Expect OpenZeppelin 5.0 custom error
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        feeManager.setCustomFees(bob, 1, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        feeManager.setDefaultFees(1, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        feeManager.removeCustomFees(bob);
    }
}
