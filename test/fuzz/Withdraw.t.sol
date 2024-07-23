// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "../ERC4626StrategyTest.t.sol";

contract WithdrawFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    function testFuzz_Withdraw_Normal(uint256[5] memory amounts) public {
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

            uint256 strategyAssets = ERC4626(strategyAsset).convertToAssets(
                IERC20(strategyAsset).balanceOf(address(strategy))
            );
            vm.startPrank(alice);
            if (amounts[i] >= strategyAssets) {
                amounts[i] = strategyAssets;
            }
            uint256 previewedWithdraw = strategy.previewWithdraw(amounts[i]);
            uint256 withdrawed = strategy.withdraw(amounts[i], alice, alice);
            vm.stopPrank();

            assertEq(previewedWithdraw, withdrawed);
            assertEq(IERC20(asset).balanceOf(alice), previousAssetBalance + amounts[i]);

            uint256 assetsHeld = ERC4626(strategyAsset).convertToShares(
                totalAmounts - previousAssetBalance - amounts[i]
            );
            assertLe(IERC20(strategyAsset).balanceOf(address(strategy)), assetsHeld);
            assertGe(IERC20(strategyAsset).balanceOf(address(strategy)), assetsHeld.zeroFloorSub(5));
            assertEq(strategy.balanceOf(alice), previousBalance - previewedWithdraw);
        }
    }
}
