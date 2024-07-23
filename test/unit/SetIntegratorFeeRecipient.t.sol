// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetIntegratorFeeRecipientTest is ERC4626StrategyTest {
    function test_setIntegratorFeeRecipient_Normal() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.IntegratorFeeRecipientUpdated(alice);
        vm.prank(integrator);
        strategy.setIntegratorFeeRecipient(alice);
        assertEq(strategy.integratorFeeRecipient(), alice);
    }

    function test_setIntegratorFeeRecipient_NotIntegrator() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.INTEGRATOR_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setIntegratorFeeRecipient(alice);
    }

    function test_setIntegratorFeeRecipient_ZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(integrator);
        strategy.setIntegratorFeeRecipient(address(0));
    }
}
