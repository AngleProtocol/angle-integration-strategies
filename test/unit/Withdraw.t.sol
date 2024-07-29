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

    function test_Withdraw_Profit() public {
        uint256 previousBalance = strategy.balanceOf(alice);
        uint256 assets = strategy.convertToAssets(previousBalance);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.startPrank(alice);
        uint256 previewedWithdraw = strategy.previewWithdraw(assets);
        uint256 withdrawed = strategy.withdraw(assets, alice, alice);
        vm.stopPrank();

        assertEq(previewedWithdraw, withdrawed);
        assertEq(IERC20(asset).balanceOf(alice), assets);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), previousBalance - previewedWithdraw);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }

    function test_Withdraw_MultipleProfit() public {
        uint256 previousBalance = strategy.balanceOf(alice);
        uint256 assets = strategy.convertToAssets(previousBalance);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.startPrank(alice);
        uint256 previewedWithdraw = strategy.previewWithdraw(assets / 2);
        uint256 withdrawed = strategy.withdraw(assets / 2, alice, alice);
        vm.stopPrank();

        assertEq(previewedWithdraw, withdrawed);
        assertEq(IERC20(asset).balanceOf(alice), assets / 2);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), previousBalance - previewedWithdraw);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);

        uint256 previousAssetBalance = IERC20(asset).balanceOf(alice);

        feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.startPrank(alice);
        previewedWithdraw = strategy.previewWithdraw(assets / 2);
        withdrawed = strategy.withdraw(assets / 2, alice, alice);
        vm.stopPrank();

        assertEq(previewedWithdraw, withdrawed);
        assertEq(IERC20(asset).balanceOf(alice), previousAssetBalance + assets / 2);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }

    function test_Withdraw_Loss() public {
        uint256 previousBalance = strategy.balanceOf(alice);
        vm.mockCall(strategyAsset, abi.encodeWithSelector(ERC4626.convertToAssets.selector), abi.encode(9e18));
        uint256 assets = strategy.convertToAssets(previousBalance);

        vm.startPrank(alice);
        uint256 previewedWithdraw = strategy.previewWithdraw(assets);
        uint256 withdrawed = strategy.withdraw(assets, alice, alice);
        vm.stopPrank();

        assertEq(previewedWithdraw, withdrawed);
        assertEq(IERC20(asset).balanceOf(alice), assets);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), 0);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), 0);
        assertEq(strategy.lastTotalAssets(), 0);
    }
}
