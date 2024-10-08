// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MintTest is ERC4626StrategyTest {
    function test_Mint_Profit() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);

        uint256 shares = strategy.convertToShares(100e18);
        uint256 previewedMint = strategy.previewMint(shares);
        uint256 assetsMinted = strategy.mint(shares, alice);
        vm.stopPrank();

        assertEq(assetsMinted, previewedMint);
        assertEq(ERC4626(strategyAsset).balanceOf(address(strategy)), ERC4626(strategyAsset).convertToShares(100e18));
        assertEq(IERC20(asset).balanceOf(alice), 0);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), shares);
        assertEq(strategy.totalSupply(), shares);
    }

    function test_Mint_MultipleProfit() public {
        deal(asset, alice, 200e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 200e18);

        uint256 shares = strategy.convertToShares(100e18);
        strategy.mint(shares, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        shares = strategy.convertToShares(100e18);
        uint256 previewedMint = strategy.previewMint(shares);
        uint256 previousBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        vm.prank(alice);
        uint256 assetsMinted = strategy.mint(shares, alice);

        assertEq(shares, 99856429656079656377);
        assertApproxEqRel(strategy.lastTotalAssets(), strategy.totalAssets(), 1);
        assertEq(assetsMinted, previewedMint);
        assertEq(strategy.balanceOf(alice), shares);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
        assertEq(
            ERC4626(strategyAsset).balanceOf(address(strategy)),
            previousBalance + ERC4626(strategyAsset).convertToShares(previewedMint)
        );
    }

    function test_Mint_MultipleLoss() public {
        deal(asset, alice, 200e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 200e18);

        uint256 shares = strategy.convertToShares(100e18);
        strategy.mint(shares, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        vm.mockCall(strategyAsset, abi.encodeWithSelector(ERC4626.convertToAssets.selector), abi.encode(9e18));
        shares = strategy.convertToShares(100e18);
        uint256 previewedMint = strategy.previewMint(shares);

        vm.prank(alice);
        uint256 assetsMinted = strategy.mint(shares, alice);

        assertEq(shares, 1111111111111111110998);
        assertEq(assetsMinted, previewedMint);
        assertEq(strategy.balanceOf(alice), shares);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), 0);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), 0);
    }
}
