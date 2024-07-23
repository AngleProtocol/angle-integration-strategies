// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract RedeemFuzzTest is ERC4626StrategyTest {
    function testFuzz_Redeem_Normal(uint256[5] memory amounts) public {
        uint256 totalAmounts;
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 1e21);
            totalAmounts += amounts[i];
        }
        deal(asset, alice, totalAmounts);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), totalAmounts);
        strategy.deposit(totalAmounts, alice);
        vm.stopPrank();

        for (uint256 i = 0; i < 5; i++) {
            uint256 previousBalance = strategy.balanceOf(alice);
            uint256 previousAssetBalance = IERC20(asset).balanceOf(alice);

            vm.startPrank(alice);
            uint256 previewedRedeem = strategy.previewRedeem(amounts[i]);
            uint256 redeemed = strategy.redeem(amounts[i], alice, alice);
            vm.stopPrank();

            assertEq(previewedRedeem, redeemed);
            assertEq(IERC20(asset).balanceOf(alice), previousAssetBalance + previewedRedeem);
            assertEq(strategy.balanceOf(alice), previousBalance - amounts[i]);
        }
    }
}
