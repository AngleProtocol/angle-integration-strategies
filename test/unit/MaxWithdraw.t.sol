// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MaxWithdrawTest is ERC4626StrategyTest {
    function test_MaxWithdraw_Normal() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        assertEq(strategy.maxWithdraw(alice), strategy.convertToAssets(strategy.balanceOf(alice)));
    }

    function test_MaxWithdraw_HigherThanMaxWithdraw() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        vm.mockCall(
            strategyAsset,
            abi.encodeWithSelector(ERC4626.maxWithdraw.selector, address(strategy)),
            abi.encode(50e18)
        );
        assertEq(strategy.maxWithdraw(alice), 50e18);
    }
}
