// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";
import { MockRouter } from "../mock/MockRouter.sol";

contract SwapTest is ERC4626StrategyTest {
    MockRouter router;

    function setUp() public override {
        super.setUp();

        router = new MockRouter();
        vm.startPrank(developer);
        strategy.setSwapRouter(address(router));
        strategy.setTokenTransferAddress(address(router));
        vm.stopPrank();
    }

    function test_swap_normal() public {
        deal(USDC, address(strategy), 100e18);
        deal(asset, address(router), 100e18);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(MockRouter.swap.selector, 100e18, USDC, 100e18, asset);

        vm.prank(keeper);
        strategy.swap(tokens, data, amounts);

        uint256 strategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

        assertEq(IERC20(USDC).allowance(address(strategy), address(router)), 0);
        assertEq(strategyBalance, ERC4626(strategyAsset).convertToShares(100e18));
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);

        assertEq(strategy.vestingProfit(), 100e18);
        assertEq(strategy.lastUpdate(), block.timestamp);
        assertEq(strategy.lockedProfit(), 100e18);
        assertEq(strategy.totalAssets(), 0);

        // Check for linear vesting
        vm.warp(block.timestamp + (strategy.vestingPeriod() / 2));
        assertEq(strategy.lockedProfit(), 50e18);
        assertEq(strategy.totalAssets(), ERC4626(strategyAsset).convertToAssets(strategyBalance) - 50e18);

        vm.warp(block.timestamp + strategy.vestingPeriod());
        assertEq(strategy.lockedProfit(), 0);
        assertEq(strategy.totalAssets(), ERC4626(strategyAsset).convertToAssets(strategyBalance));
    }

    function test_swap_OutgoingAssets() public {
        deal(asset, address(strategy), 100e18);
        deal(asset, address(router), 100e18);

        address[] memory tokens = new address[](1);
        tokens[0] = asset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(MockRouter.swap.selector, 100e18, asset, 10e18, asset);

        vm.expectRevert(OutgoingAssets.selector);
        vm.prank(keeper);
        strategy.swap(tokens, data, amounts);
    }

    function test_swap_OutgoingStrategyAssets() public {
        deal(strategyAsset, address(strategy), 100e18);

        address[] memory tokens = new address[](1);
        tokens[0] = strategyAsset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(MockRouter.swap.selector, 100e18, strategyAsset, 10e18, strategyAsset);

        vm.expectRevert(OutgoingAssets.selector);
        vm.prank(keeper);
        strategy.swap(tokens, data, amounts);
    }
}
