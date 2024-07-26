// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetDeveloperFeeRecipientTest is ERC4626StrategyTest {
    function test_setDeveloperFeeRecipient_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.DeveloperFeeRecipientUpdated(alice);
        vm.prank(developer);
        strategy.setDeveloperFeeRecipient(alice);
        assertEq(strategy.developerFeeRecipient(), alice);
    }

    function test_setDeveloperFeeRecipient_NotDeveloper() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.DEVELOPER_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setDeveloperFeeRecipient(alice);
    }

    function test_setDeveloperFeeRecipient_ZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(developer);
        strategy.setDeveloperFeeRecipient(address(0));
    }
}
