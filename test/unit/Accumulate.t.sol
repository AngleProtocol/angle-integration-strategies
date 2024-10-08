// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract AccumulateTest is ERC4626StrategyTest {
    function test_Accumulate_Profit() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();
        uint256 balance = ERC4626(strategyAsset).balanceOf(address(strategy));
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        vm.warp(block.timestamp + 1 weeks);

        uint256 totalAssets = strategy.totalAssets();
        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        strategy.accumulate();

        assertEq(strategy.lastTotalAssets(), ERC4626(strategyAsset).convertToAssets(balance));
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
    }

    function test_Accumulate_Loss() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 weeks);

        vm.mockCall(strategyAsset, abi.encodeWithSelector(ERC4626.convertToAssets.selector), abi.encode(9e18));
        strategy.accumulate();

        assertEq(strategy.totalAssets(), 9e18);
        assertEq(strategy.lastTotalAssets(), 9e18);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), 0);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), 0);
    }
}
