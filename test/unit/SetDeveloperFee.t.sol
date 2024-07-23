// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract SetDeveloperFeeTest is ERC4626StrategyTest {
    function test_setDeveloperFee_Normal() public {
        vm.expectEmit(true, true, true, true);
        emit BaseStrategy.DeveloperFeeUpdated(10_000);
        vm.prank(developer);
        strategy.setDeveloperFee(10_000);
        assertEq(strategy.developerFee(), 10_000);
    }

    function test_setDeveloperFee_NotDeveloper() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                strategy.DEVELOPER_ROLE()
            )
        );
        vm.prank(bob);
        strategy.setDeveloperFee(10_000);
    }

    function test_setDeveloperFee_InvalidFee() public {
        vm.expectRevert(InvalidFee.selector);
        vm.prank(developer);
        strategy.setDeveloperFee(50_001);
    }
}
