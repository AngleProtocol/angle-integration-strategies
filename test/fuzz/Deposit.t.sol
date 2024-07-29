// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "../ERC4626StrategyTest.t.sol";

contract DepositFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    function testFuzz_Deposit_Success(uint256[5] memory amounts, uint256[5] memory totalAssets) public {
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 1e21);
            totalAssets[i] = bound(totalAssets[i], 1e18, 1e24);
            deal(asset, alice, amounts[i]);

            uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
            uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());
            uint256 previousBalance = strategy.balanceOf(alice);
            uint256 previousStrategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

            vm.mockCall(
                strategyAsset,
                abi.encodeWithSelector(ERC4626.convertToAssets.selector),
                abi.encode(totalAssets[i])
            );
            uint256 storedTotalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();
            uint256 feeShares = strategy.convertToShares(
                ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );

            vm.startPrank(alice);
            IERC20(asset).approve(address(strategy), amounts[i]);
            uint256 previewedDeposit = strategy.previewDeposit(amounts[i]);
            uint256 deposited = strategy.deposit(amounts[i], alice);
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

            assertEq(previewedDeposit, deposited);
            assertEq(
                ERC4626(strategyAsset).balanceOf(address(strategy)),
                previousStrategyBalance + ERC4626(strategyAsset).convertToShares(amounts[i])
            );
            assertEq(IERC20(asset).balanceOf(alice), 0);
            assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
            assertEq(
                strategy.totalSupply(),
                previousBalance + previewedDeposit + feeShares + previousIntegratorBalance + previousDeveloperBalance
            );
            assertEq(strategy.balanceOf(alice), previousBalance + previewedDeposit);
        }
    }
}
