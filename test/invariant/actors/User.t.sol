// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import { StateVariableStore } from "../stores/StateVariableStore.sol";
import "./BaseActor.t.sol";

contract UserActor is BaseActor {
    using UtilsLib for uint256;

    StateVariableStore public stateVariableStore;

    constructor(
        uint256 _nbrActor,
        address _strategy,
        StateVariableStore _stateVariableStore
    ) BaseActor(_nbrActor, "user", _strategy) {
        stateVariableStore = _stateVariableStore;
    }

    function deposit(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        amount = bound(amount, 1e18, 1e21);

        uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
        uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());
        uint256 previousBalance = strategy.balanceOf(_currentActor);
        uint256 previousStrategyBalance = strategyAsset.balanceOf(address(strategy));

        uint256 feeShares;
        {
            uint256 storedTotalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();
            feeShares = strategy.convertToShares(
                ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );
        }

        asset.approve(address(strategy), amount);
        uint256 previewedDeposit = strategy.previewDeposit(amount);
        uint256 deposited = strategy.deposit(amount, _currentActor);

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

        assertEq(previewedDeposit, deposited);
        assertEq(
            strategyAsset.balanceOf(address(strategy)),
            previousStrategyBalance + strategyAsset.convertToShares(amount)
        );
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOf(_currentActor), previousBalance + previewedDeposit);

        stateVariableStore.addUnderlyingStrategyShares(strategyAsset.convertToShares(amount));
        stateVariableStore.addShares(deposited + feeShares);
    }

    function withdraw(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        if (amount > strategy.maxWithdraw(_currentActor)) {
            return;
        }

        uint256 previousBalance = strategy.balanceOf(_currentActor);
        uint256 previousAssetBalance = asset.balanceOf(_currentActor);
        uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
        uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());

        uint256 feeShares;
        {
            uint256 storedTotalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();
            feeShares = strategy.convertToShares(
                ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );
        }

        uint256 previewedWithdraw = strategy.previewWithdraw(amount);
        uint256 withdrawed = strategy.withdraw(amount, _currentActor, _currentActor);

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

        assertEq(previewedWithdraw, withdrawed);
        assertEq(asset.balanceOf(_currentActor), previousAssetBalance + amount);
        assertEq(strategy.balanceOf(_currentActor), previousBalance - previewedWithdraw);

        stateVariableStore.removeUnderlyingStrategyShares(strategyAsset.convertToShares(amount));
        stateVariableStore.removeShares(withdrawed);
        stateVariableStore.addShares(feeShares);
    }

    function mint(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        amount = bound(amount, 1e18, 1e21);
        uint256 assets = strategy.convertToAssets(amount);

        uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
        uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());
        uint256 previousBalance = strategy.balanceOf(_currentActor);
        uint256 previousStrategyBalance = strategyAsset.balanceOf(address(strategy));

        uint256 feeShares;
        {
            uint256 storedTotalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();
            feeShares = strategy.convertToShares(
                ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );
        }

        asset.approve(address(strategy), assets);

        uint256 previewedMint = strategy.previewMint(amount);
        uint256 assetsMinted = strategy.mint(amount, _currentActor);

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
            strategyAsset.balanceOf(address(strategy)),
            previousStrategyBalance + strategyAsset.convertToShares(previewedMint)
        );
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(
            strategy.totalSupply(),
            previousBalance + amount + feeShares + previousIntegratorBalance + previousDeveloperBalance
        );
        assertEq(strategy.balanceOf(_currentActor), previousBalance + amount);

        stateVariableStore.addUnderlyingStrategyShares(strategyAsset.convertToShares(assets));
        stateVariableStore.addShares(feeShares + amount);
    }

    function redeem(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        if (amount > strategy.maxRedeem(_currentActor)) {
            return;
        }

        uint256 previousBalance = strategy.balanceOf(_currentActor);
        uint256 previousAssetBalance = asset.balanceOf(_currentActor);
        uint256 previousDeveloperBalance = strategy.balanceOf(strategy.developerFeeRecipient());
        uint256 previousIntegratorBalance = strategy.balanceOf(strategy.integratorFeeRecipient());

        uint256 feeShares;
        {
            uint256 storedTotalAssets = strategy.totalAssets();
            uint256 lastTotalAssets = strategy.lastTotalAssets();
            feeShares = strategy.convertToShares(
                ((storedTotalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
            );
        }

        uint256 previewedRedeem = strategy.previewRedeem(amount);
        uint256 redeemed = strategy.redeem(amount, _currentActor, _currentActor);

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

        assertEq(previewedRedeem, redeemed);
        assertEq(asset.balanceOf(_currentActor), previousAssetBalance + previewedRedeem);
        assertEq(strategy.balanceOf(_currentActor), previousBalance - amount);

        stateVariableStore.removeUnderlyingStrategyShares(strategyAsset.convertToShares(redeemed));
        stateVariableStore.removeShares(amount);
        stateVariableStore.addShares(feeShares);
    }
}
