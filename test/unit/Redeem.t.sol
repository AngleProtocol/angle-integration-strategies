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

    function test_Redeem_Success() public {
        uint256 previousBalance = strategy.balanceOf(alice);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();

        vm.startPrank(alice);
        uint256 previewedRedeem = strategy.previewRedeem(previousBalance);
        uint256 redeemed = strategy.redeem(previousBalance, alice, alice);
        vm.stopPrank();

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        assertEq(previewedRedeem, redeemed);
        assertEq(IERC20(asset).balanceOf(alice), previewedRedeem);
        assertEq(strategy.balanceOf(alice), 0);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }
}
