// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract RedeemTest is ERC4626StrategyTest {
    function setUp() public override {
        super.setUp();

        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);
    }

    function test_Redeem_Profit() public {
        uint256 previousBalance = strategy.balanceOf(alice);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        uint256 totalSupply = strategy.totalSupply();

        vm.startPrank(alice);
        uint256 previewedRedeem = strategy.previewRedeem(previousBalance);
        uint256 redeemed = strategy.redeem(previousBalance, alice, alice);
        vm.stopPrank();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        assertEq(redeemed, 100143776764715923817); // profit 159751960795470907
        assertEq(previewedRedeem, redeemed);
        assertEq(redeemed, (totalAssets * previousBalance) / (totalSupply + feeShares));
        assertEq(IERC20(asset).balanceOf(alice), previewedRedeem);
        assertEq(strategy.balanceOf(alice), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }

    function test_Redeem_MultipleProfit() public {
        uint256 previousBalance = strategy.balanceOf(alice);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        uint256 totalSupply = strategy.totalSupply();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.startPrank(alice);
        uint256 previewedRedeem = strategy.previewRedeem(previousBalance / 2);
        uint256 redeemed = strategy.redeem(previousBalance / 2, alice, alice);
        vm.stopPrank();

        assertEq(previewedRedeem, redeemed);
        assertEq(redeemed, (totalAssets * (previousBalance / 2)) / (totalSupply + feeShares));
        assertEq(IERC20(asset).balanceOf(alice), previewedRedeem);
        assertEq(strategy.balanceOf(alice), previousBalance / 2);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);

        uint256 previousAssetBalance = IERC20(asset).balanceOf(alice);

        feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.startPrank(alice);
        previewedRedeem = strategy.previewRedeem(previousBalance / 2);
        redeemed = strategy.redeem(previousBalance / 2, alice, alice);
        vm.stopPrank();

        assertEq(previewedRedeem, redeemed);
        assertEq(redeemed, (totalAssets * (previousBalance / 2)) / (totalSupply + feeShares));
        assertEq(IERC20(asset).balanceOf(alice), previousAssetBalance + previewedRedeem);
        assertEq(strategy.balanceOf(alice), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }

    function test_Redeem_Loss() public {
        vm.mockCall(strategyAsset, abi.encodeWithSelector(ERC4626.convertToAssets.selector), abi.encode(9e18));
        uint256 previousBalance = strategy.balanceOf(alice);

        uint256 totalAssets = strategy.totalAssets();
        uint256 totalSupply = strategy.totalSupply();

        vm.startPrank(alice);
        uint256 previewedRedeem = strategy.previewRedeem(previousBalance);
        uint256 redeemed = strategy.redeem(previousBalance, alice, alice);
        vm.stopPrank();

        assertEq(redeemed, 9e18);
        assertEq(previewedRedeem, redeemed);
        assertEq(redeemed, (totalAssets * previousBalance) / totalSupply);
        assertEq(IERC20(asset).balanceOf(alice), previewedRedeem);
        assertEq(strategy.balanceOf(alice), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), 0);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), 0);
        assertEq(strategy.lastTotalAssets(), 0);
    }
}
