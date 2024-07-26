// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./BaseActor.t.sol";

contract ParamActor is BaseActor {
    constructor(uint256 _nbrActor, address _strategy) BaseActor(_nbrActor, "param", _strategy) {}

    function warp(uint256 timeForward) public {
        timeForward = bound(timeForward, 1, 1 weeks);

        vm.warp(block.timestamp + timeForward);
    }
}
