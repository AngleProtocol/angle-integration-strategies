// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract RecoverTokensTest is ERC4626StrategyTest {
    function test_recoverTokens_Success() public {
        deal(USDC, address(strategy), 10e18);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        vm.prank(keeper);
        strategy.recoverTokens(tokens, alice);

        assertEq(IERC20(USDC).balanceOf(alice), 10e18);
    }

    function test_recoverTokens_IgnoreAsset() public {
        deal(USDC, address(strategy), 10e18);
        deal(asset, address(strategy), 10e18);

        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = asset;

        vm.prank(keeper);
        strategy.recoverTokens(tokens, alice);

        assertEq(IERC20(USDC).balanceOf(alice), 10e18);
        assertEq(IERC20(asset).balanceOf(alice), 0);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 10e18);
    }

    function test_recoverTokens_IgnoreStrategyAsset() public {
        deal(USDC, address(strategy), 10e18);
        deal(strategyAsset, address(strategy), 10e18);

        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = strategyAsset;

        vm.prank(keeper);
        strategy.recoverTokens(tokens, alice);

        assertEq(IERC20(USDC).balanceOf(alice), 10e18);
        assertEq(IERC20(strategyAsset).balanceOf(alice), 0);
        assertEq(IERC20(strategyAsset).balanceOf(address(strategy)), 10e18);
    }

    function test_recoverTokens_ZeroReceiver() public {
        deal(USDC, address(strategy), 10e18);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        vm.expectRevert(ZeroAddress.selector);
        vm.prank(keeper);
        strategy.recoverTokens(tokens, address(0));
    }
}
