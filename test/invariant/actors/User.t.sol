// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./BaseActor.t.sol";

contract UserActor is BaseActor {
    constructor(uint256 _nbrActor, address _strategy) BaseActor(_nbrActor, "user", _strategy) {}

    function deposit(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        deal(address(asset), _currentActor, amount);
        strategy.deposit(amount, _currentActor);
    }

    function withdraw(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        if (amount > strategy.maxWithdraw(_currentActor)) {
            return;
        }

        strategy.withdraw(amount, _currentActor, _currentActor);
    }

    function mint(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        uint256 assets = strategy.convertToAssets(amount);
        deal(address(asset), address(strategy), assets);

        strategy.mint(amount, _currentActor);
    }

    function redeem(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        if (amount > strategy.maxRedeem(_currentActor)) {
            return;
        }

        strategy.redeem(amount, _currentActor, _currentActor);
    }
}
