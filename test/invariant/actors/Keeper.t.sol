// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./BaseActor.t.sol";

contract KeeperActor is BaseActor {
    constructor(uint256 _nbrActor, address _strategy) BaseActor(_nbrActor, "keeper", _strategy) {}

    function swap(uint256 actorIndexSeed, uint256 tokenIn, uint256 tokenOut) public useActor(actorIndexSeed) {
        tokenIn = bound(tokenIn, 1e18, 1e21);
        tokenOut = bound(tokenOut, 1e18, 1e21);

        deal(USDC, address(strategy), tokenIn);
        deal(address(asset), address(router), tokenOut);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = tokenIn;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(MockRouter.swap.selector, tokenIn, USDC, tokenOut, asset);
    }

    function accumulate(uint256 actorIndexSeed) public useActor(actorIndexSeed) {
        strategy.accumulate();
    }
}
