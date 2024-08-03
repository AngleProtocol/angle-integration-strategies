// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetTokenTransferAddressTest is ERC4626StrategyTest {
    function test_setTokenTransferAddress_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.TokenTransferAddressUpdated(alice);
        vm.prank(developer);
        strategy.setTokenTransferAddress(alice);
        assertEq(strategy.tokenTransferAddress(), alice);
    }

    function test_setTokenTransferAddress_NotDeveloper() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.DEVELOPER_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setTokenTransferAddress(alice);
    }

    function test_setTokenTransferAddress_ZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(developer);
        strategy.setTokenTransferAddress(address(0));
    }
}
