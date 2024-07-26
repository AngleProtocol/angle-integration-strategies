// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetPerformanceFeeTest is ERC4626StrategyTest {
    function test_setPerformanceFee_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.PerformanceFeeUpdated(10_000);
        vm.prank(integrator);
        strategy.setPerformanceFee(10_000);
        assertEq(strategy.performanceFee(), 10_000);
    }

    function test_setPerformanceFee_NotIntegrator() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.INTEGRATOR_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setPerformanceFee(10_000);
    }

    function test_setPerformanceFee_InvalidFee() public {
        vm.expectRevert(InvalidFee.selector);
        vm.prank(integrator);
        strategy.setPerformanceFee(100_001);
    }
}
