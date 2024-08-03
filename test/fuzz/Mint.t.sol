// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "../ERC4626StrategyTest.t.sol";

contract MintFuzzTest is ERC4626StrategyTest {
    using UtilsLib for uint256;

    function setUp() public override {
        super.setUp();

        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();
    }

    function testFuzz_Mint_Success(uint256[5] memory amounts, uint256[5] memory totalAssets) public {
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 1e21);
            totalAssets[i] = bound(totalAssets[i], 1e21, 1e24);
            deal(asset, alice, amounts[i]);

            uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
            uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());
            uint256 previousBalance = strategy.balanceOf(alice);
            uint256 previousStrategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

            vm.mockCall(
                strategyAsset,
                abi.encodeWithSelector(ERC4626.convertToAssets.selector),
                abi.encode(totalAssets[i])
            );
            uint256 feeShares;
            {
                uint256 storedTotalAssets = strategy.totalAssets();
                uint256 lastTotalAssets = strategy.lastTotalAssets();
                feeShares = strategy.convertToShares(
                    ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
                );
            }

            vm.startPrank(alice);
            IERC20(asset).approve(address(strategy), amounts[i]);

            uint256 shares = strategy.convertToShares(amounts[i]);
            uint256 previewedMint = strategy.previewMint(shares);
            uint256 assetsMinted = strategy.mint(shares, alice);
            vm.stopPrank();

            {
                uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();
                assertEq(
                    strategy.balanceOf(strategy.integratorFeeRecipient()),
                    previousIntegratorBalance + feeShares - developerFeeShares
                );
                assertEq(
                    strategy.balanceOf(strategy.developerFeeRecipient()),
                    previousDeveloperBalance + developerFeeShares
                );
            }

            assertEq(assetsMinted, previewedMint);
            assertEq(
                ERC4626(strategyAsset).balanceOf(address(strategy)),
                previousStrategyBalance + ERC4626(strategyAsset).convertToShares(previewedMint)
            );
            assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
            assertEq(
                strategy.totalSupply(),
                previousBalance + shares + feeShares + previousIntegratorBalance + previousDeveloperBalance
            );
            assertEq(strategy.balanceOf(alice), previousBalance + shares);
        }
    }
}
