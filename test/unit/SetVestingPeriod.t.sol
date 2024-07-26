// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetVestingPeriodTest is ERC4626StrategyTest {
    function test_setVestingPeriod_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.VestingPeriodUpdated(2 weeks);
        vm.prank(integrator);
        strategy.setVestingPeriod(2 weeks);
        assertEq(strategy.vestingPeriod(), 2 weeks);
    }

    function test_setVestingPeriod_NotIntegrator() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.INTEGRATOR_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setVestingPeriod(2 weeks);
    }
}
