// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./BaseActor.t.sol";

contract DeveloperActor is BaseActor {
    constructor(uint256 _nbrActor, address _strategy) BaseActor(_nbrActor, "developer", _strategy) {}

    function setDeveloperFeeRecipient(uint256 actorIndexSeed) public useActor(actorIndexSeed) {
        strategy.setDeveloperFeeRecipient(_currentActor);
    }

    function setDeveloperFee(uint256 actorIndexSeed, uint32 fee) public useActor(actorIndexSeed) {
        fee = uint32(bound(fee, 0, strategy.MAX_FEE()));

        strategy.setDeveloperFee(fee);
    }
}
