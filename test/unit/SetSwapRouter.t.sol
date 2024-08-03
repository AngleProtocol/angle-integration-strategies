// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetSwapRouterTest is ERC4626StrategyTest {
    function test_setSwapRouter_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.SwapRouterUpdated(alice);
        vm.prank(developer);
        strategy.setSwapRouter(alice);
        assertEq(strategy.swapRouter(), alice);
    }

    function test_setSwapRouter_NotDeveloper() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.DEVELOPER_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setSwapRouter(alice);
    }

    function test_setSwapRouter_ZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(developer);
        strategy.setSwapRouter(address(0));
    }
}
