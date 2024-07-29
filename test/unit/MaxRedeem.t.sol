// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MaxRedeemTest is ERC4626StrategyTest {
    function test_MaxRedeem_Success() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        assertApproxEqRel(strategy.maxRedeem(alice), strategy.balanceOf(alice), 1);
    }

    function test_MaxRedeem_HigherThanMaxWithdraw() public {
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
        uint256 maxRedeem = strategy.maxRedeem(alice);
        assertEq(maxRedeem, strategy.convertToShares(50e18));
    }
}
