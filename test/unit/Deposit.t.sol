// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract DepositTest is ERC4626StrategyTest {
    function test_Deposit_Success() public {
        deal(asset, alice, 100e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 100e18);

        uint256 previewedDeposit = strategy.previewDeposit(100e18);
        strategy.deposit(100e18, alice);
        vm.stopPrank();

        assertEq(ERC4626(strategyAsset).balanceOf(address(strategy)), ERC4626(strategyAsset).convertToShares(100e18));
        assertEq(IERC20(asset).balanceOf(alice), 0);
        assertEq(IERC20(asset).balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(alice), previewedDeposit);
        assertEq(strategy.totalSupply(), previewedDeposit);
    }

    function test_Deposit_MultipleProfit() public {
        deal(asset, alice, 200e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 200e18);
        strategy.deposit(100e18, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        uint256 previewedDeposit = strategy.previewDeposit(100e18);
        uint256 previousBalance = ERC4626(strategyAsset).balanceOf(address(strategy));

        vm.prank(alice);
        strategy.deposit(100e18, alice);

        uint256 feeShares = strategy.convertToShares(
            ((totalAssets - lastTotalAssets) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShares = (feeShares * strategy.developerFee()) / strategy.BPS();

        assertLe(strategy.lastTotalAssets() - 1, strategy.totalAssets());
        assertGe(strategy.lastTotalAssets(), strategy.totalAssets());
        assertEq(strategy.balanceOf(alice), previewedDeposit);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), feeShares - developerFeeShares);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), developerFeeShares);
        assertEq(
            ERC4626(strategyAsset).balanceOf(address(strategy)),
            previousBalance + ERC4626(strategyAsset).convertToShares(100e18)
        );
    }

    function test_Deposit_MultipleLoss() public {
        deal(asset, alice, 200e18);

        vm.startPrank(alice);
        IERC20(asset).approve(address(strategy), 200e18);
        strategy.deposit(100e18, bob);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        vm.mockCall(strategyAsset, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(9e18));
        uint256 previewedDeposit = strategy.previewDeposit(100e18);

        vm.prank(alice);
        vm.mockCall(strategyAsset, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(9e18));
        strategy.deposit(100e18, alice);

        assertEq(strategy.balanceOf(alice), previewedDeposit);
        assertEq(strategy.balanceOf(strategy.integratorFeeRecipient()), 0);
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), 0);
    }
}
