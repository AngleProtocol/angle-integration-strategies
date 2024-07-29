// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "../ERC4626StrategyTest.t.sol";

contract RedeemFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    function setUp() public override {
        super.setUp();

        deal(asset, alice, 1e24);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 1e24);
        strategy.deposit(1e24, alice);
        vm.stopPrank();
    }

    function testFuzz_Redeem_Success(uint256[5] memory amounts, uint256[5] memory totalAssets) public {
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 1e21);
            totalAssets[i] = bound(totalAssets[i], 1e21, 1e24);
        }

        for (uint256 i = 0; i < 5; i++) {
            uint256 previousBalance = strategy.balanceOf(alice);
            uint256 previousAssetBalance = IERC20(asset).balanceOf(alice);
            uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
            uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());

            vm.mockCall(
                strategyAsset,
                abi.encodeWithSelector(ERC4626.convertToAssets.selector),
                abi.encode(totalAssets[i])
            );
            uint256 feeShares;
            {
                uint256 storedTotalAssets = strategy.totalAssets();
                uint256 lastTotalAssets = strategy.lastTotalAssets();
                feeShares = strategy.convertToShares(
                    ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
                );
            }

            vm.startPrank(alice);
            uint256 previewedRedeem = strategy.previewRedeem(amounts[i]);
            uint256 redeemed = strategy.redeem(amounts[i], alice, alice);
            vm.stopPrank();

            {
                uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();
                assertEq(
                    strategy.balanceOf(strategy.integratorFeeRecipient()),
                    previousIntegratorBalance + feeShares - developerFeeShares
                );
                assertEq(
                    strategy.balanceOf(strategy.developerFeeRecipient()),
                    previousDeveloperBalance + developerFeeShares
                );
            }

            assertEq(previewedRedeem, redeemed);
            assertEq(IERC20(asset).balanceOf(alice), previousAssetBalance + previewedRedeem);
            assertEq(strategy.balanceOf(alice), previousBalance - amounts[i]);
        }
    }
}
