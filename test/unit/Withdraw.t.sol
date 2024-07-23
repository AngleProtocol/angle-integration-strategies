// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract WithdrawTest is ERC4626StrategyTest {
    function setUp() public override {
        super.setUp();

        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);
    }

    function test_Withdraw_Normal() public {
        uint256 previousBalance = strategy.balanceOf(alice);
        uint256 assets = strategy.convertToAssets(previousBalance);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();

        vm.startPrank(alice);
        uint256 previewedWithdraw = strategy.previewWithdraw(assets);
        uint256 withdrawed = strategy.withdraw(assets, alice, alice);
        vm.stopPrank();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        assertEq(previewedWithdraw, withdrawed);
        assertEq(IERC20(asset).balanceOf(alice), assets);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), previousBalance - previewedWithdraw);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }
}
