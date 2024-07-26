// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "../ERC4626StrategyTest.t.sol";

contract AccumulateFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    function testFuzz_accumulate_Success(
        uint256 depositAmount,
        uint256[5] memory timeOffsets,
        uint256[5] memory balances
    ) public {
        depositAmount = bound(depositAmount, 1e18, 1e21);
        deal(asset, alice, depositAmount);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 integratorShares = 0;
        uint256 developerShares = 0;

        for (uint256 i = 0; i < 5; i++) {
            timeOffsets[i] = bound(timeOffsets[i], 1, 365 days);
            vm.warp(block.timestamp + timeOffsets[i]);

            balances[i] = bound(balances[i], 1, 1e22);
            vm.mockCall(strategyAsset, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(balances[i]));
            uint256 totalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();

            vm.mockCall(strategyAsset, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(balances[i]));
            strategy.accumulate();

            uint256 feeShare = strategy.convertToShares(
                ((totalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );
            uint256 developerFeeShare = (feeShare * strategy.developerFee()) / strategy.BPS();

            integratorShares += feeShare - developerFeeShare;
            developerShares += developerFeeShare;
            assertEq(strategy.lastTotalAssets(), totalAssets);
            assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), integratorShares);
            assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerShares);
        }
    }
}
