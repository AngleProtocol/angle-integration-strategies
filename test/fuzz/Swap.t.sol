// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import { MockRouter } from "../mock/MockRouter.sol";
import "../ERC4626StrategyTest.t.sol";

contract SwapFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    MockRouter router;

    function setUp() public override {
        super.setUp();

        router = new MockRouter();
        vm.startPrank(developer);
        strategy.setSwapRouter(address(router));
        strategy.setTokenTransferAddress(address(router));
        vm.stopPrank();
    }

    function testFuzz_swap_normal(
        uint256[5] memory amountIns,
        uint256[5] memory amountOuts,
        uint256[5] memory timeOffsets
    ) public {
        uint256 lastLockedProfit;
        for (uint256 i = 0; i < 5; ++i) {
            amountIns[i] = bound(amountIns[i], 1e18, 1e21);
            amountOuts[i] = bound(amountOuts[i], 1e18, 1e21);
            timeOffsets[i] = bound(timeOffsets[i], 1 days, 3 weeks);

            deal(USDC, address(strategy), amountIns[i]);
            deal(asset, address(router), amountOuts[i]);

            address[] memory tokens = new address[](1);
            tokens[0] = USDC;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountIns[i];
            bytes[] memory data = new bytes[](1);
            data[0] = abi.encodeWithSelector(MockRouter.swap.selector, amountIns[i], USDC, amountOuts[i], asset);

            uint256 strategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));
            uint256 lockedProfit = strategy.lockedProfit();

            vm.prank(keeper);
            strategy.swap(tokens, data, amounts);

            assertEq(IERC20(USDC).allowance(address(strategy), address(router)), 0);
            assertEq(
                ERC4626(strategyAsset).balanceOf(address(strategy)),
                strategyBalance + ERC4626(strategyAsset).convertToShares(amountOuts[i])
            );
            assertEq(IERC20(asset).balanceOf(address(strategy)), 0);

            assertEq(strategy.vestingProfit(), lockedProfit + amountOuts[i]);
            assertEq(strategy.lastUpdate(), block.timestamp);
            assertEq(
                strategy.lockedProfit(),
                strategy.vestingProfit() + (lastLockedProfit * timeOffsets[i]) / strategy.vestingPeriod()
            );
            assertEq(
                strategy.totalAssets(),
                ERC4626(strategyAsset)
                    .convertToAssets(ERC4626(strategyAsset).balanceOf(address(strategy)))
                    .zeroFloorSub(strategy.lockedProfit())
            );

            uint256 lastLockedProfit = strategy.lockedProfit();

            vm.warp(block.timestamp + timeOffsets[i]);
        }
    }
}
