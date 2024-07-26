// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract DepositFuzzTest is ERC4626StrategyTest {
    function testFuzz_Deposit_Success(uint256[5] memory amounts) public {
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 1e21);
            deal(asset, alice, amounts[i]);

            uint256 previousBalance = strategy.balanceOf(alice);
            uint256 previousStrategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

            vm.startPrank(alice);
            IERC20(asset).approve(address(strategy), amounts[i]);
            uint256 previewedDeposit = strategy.previewDeposit(amounts[i]);
            uint256 deposited = strategy.deposit(amounts[i], alice);
            vm.stopPrank();

            assertEq(previewedDeposit, deposited);
            assertEq(
                ERC4626(strategyAsset).balanceOf(address(strategy)),
                previousStrategyBalance + ERC4626(strategyAsset).convertToShares(amounts[i])
            );
            assertEq(IERC20(asset).balanceOf(alice), 0);
            assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
            assertEq(strategy.balanceOf(alice), previousBalance + previewedDeposit);
            assertEq(strategy.totalSupply(), previousBalance + previewedDeposit);
        }
    }
}
