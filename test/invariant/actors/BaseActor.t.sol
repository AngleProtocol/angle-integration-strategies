// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "../../Constants.t.sol";
import { ERC4626Strategy } from "../../../contracts/ERC4626Strategy.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { MockRouter } from "../../mock/MockRouter.sol";
import { Test, stdMath, StdStorage, stdStorage, console } from "forge-std/Test.sol";

contract BaseActor is Test {
    uint256 internal _minWallet = 0; // in base 18
    uint256 internal _maxWallet = 10 ** (18 + 12); // in base 18

    ERC4626Strategy public strategy;
    IERC20 public asset;
    address public router;

    mapping(address => uint256) public addressToIndex;
    address[] public actors;
    uint256 public nbrActor;
    address internal _currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        _currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(_currentActor, _currentActor);
        _;
        vm.stopPrank();
    }

    constructor(uint256 _nbrActor, string memory actorType, address _strategy) {
        for (uint256 i; i < _nbrActor; ++i) {
            address actor = address(uint160(uint256(keccak256(abi.encodePacked("actor", actorType, i)))));
            actors.push(actor);
            addressToIndex[actor] = i;
        }
        nbrActor = _nbrActor;

        strategy = ERC4626Strategy(_strategy);
        asset = IERC20(strategy.asset());
        router = address(strategy.swapRouter());
    }
}
