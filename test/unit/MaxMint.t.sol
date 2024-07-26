// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MaxMintTest is ERC4626StrategyTest {
    function test_MaxMint_Success() public view {
        assertEq(strategy.maxMint(alice), ERC4626(strategyAsset).maxMint(address(strategy)));
    }

    function test_MaxMint_AfterDeposit() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        assertEq(
            strategy.maxMint(alice),
            strategy.convertToShares(ERC4626(strategyAsset).maxDeposit(address(strategy)))
        );
    }
}
