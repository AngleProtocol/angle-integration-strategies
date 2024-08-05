// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./BaseActor.t.sol";

contract IntegratorActor is BaseActor {
    constructor(uint256 _nbrActor, address _strategy) BaseActor(_nbrActor, "integrator", _strategy) {}

    function setVestingPeriod(uint256 actorIndexSeed, uint64 period) public useActor(actorIndexSeed) {
        period = uint64(bound(period, 1 weeks, 30 days));

        strategy.setVestingPeriod(period);
    }

    function setPerformanceFee(uint256 actorIndexSeed, uint32 fee) public useActor(actorIndexSeed) {
        fee = uint32(bound(fee, 0, strategy.BPS()));

        strategy.setPerformanceFee(fee);
    }

    function setIntegratorFeeRecipient(uint256 actorIndexSeed) public useActor(actorIndexSeed) {
        strategy.setIntegratorFeeRecipient(_currentActor);
    }
}
