// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import { VestingStore } from "../stores/VestingStore.sol";
import { StateVariableStore } from "../stores/StateVariableStore.sol";
import "./BaseActor.t.sol";

contract KeeperActor is BaseActor {
    using UtilsLib for uint256;

    VestingStore public vestingStore;
    StateVariableStore public stateVariableStore;

    constructor(
        uint256 _nbrActor,
        address _strategy,
        StateVariableStore _stateVariableStore,
        VestingStore _vestingStore
    ) BaseActor(_nbrActor, "keeper", _strategy) {
        stateVariableStore = _stateVariableStore;
        vestingStore = _vestingStore;
    }

    function swap(uint256 actorIndexSeed, uint256 tokenIn, uint256 tokenOut) public useActor(actorIndexSeed) {
        tokenIn = bound(tokenIn, 1e18, 1e21);
        tokenOut = bound(tokenOut, 1e18, 1e21);

        deal(USDC, address(strategy), tokenIn);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = tokenIn;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(MockRouter.swap.selector, tokenIn, USDC, tokenOut, asset);

        uint256 previousLockedProfit = strategy.lockedProfit();
        strategy.swap(tokens, data, amounts);

        assertEq(strategy.lockedProfit(), previousLockedProfit + tokenOut);
        assertEq(strategy.vestingProfit(), previousLockedProfit + tokenOut);
        assertEq(strategy.lastUpdate(), block.timestamp);

        vestingStore.addVesting(block.timestamp, tokenOut, previousLockedProfit);
        stateVariableStore.addUnderlyingStrategyShares(strategyAsset.convertToShares(tokenOut));
    }

    function accumulate(uint256 actorIndexSeed, uint256 profit, uint8 negative) public useActor(actorIndexSeed) {
        uint256 assetsHeld = strategyAsset.convertToAssets(strategyAsset.balanceOf(address(strategy)));
        profit = bound(profit, 1, 1e8);

        vm.mockCall(
            address(strategyAsset),
            abi.encodeWithSelector(ERC4626.convertToAssets.selector),
            abi.encode(negative % 2 == 0 ? assetsHeld - profit : assetsHeld + profit)
        );

        uint256 totalAssets = strategy.totalAssets();
        uint256 lastTotalAssets = strategy.lastTotalAssets();
        uint256 previousDeveloperShares = strategy.balanceOf(strategy.developerFeeRecipient());
        uint256 previousIntegratorShares = strategy.balanceOf(strategy.integratorFeeRecipient());

        strategy.accumulate();

        uint256 feeShare = strategy.convertToShares(
            ((totalAssets.zeroFloorSub(lastTotalAssets)) * strategy.performanceFee()) / strategy.BPS()
        );
        uint256 developerFeeShare = (feeShare * strategy.developerFee()) / strategy.BPS();

        assertEq(strategy.lastTotalAssets(), totalAssets);
        assertEq(
            strategy.balanceOf(strategy.integratorFeeRecipient()),
            previousIntegratorShares + feeShare - developerFeeShare
        );
        assertEq(strategy.balanceOf(strategy.developerFeeRecipient()), previousDeveloperShares + developerFeeShare);

        vm.clearMockedCalls();

        stateVariableStore.addShares(feeShare);
    }
}
