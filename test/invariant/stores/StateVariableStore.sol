// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract StateVariableStore {
    uint256 public shares;
    uint256 public underlyingStrategyShares;

    function addShares(uint256 _shares) public {
        shares += _shares;
    }

    function removeShares(uint256 _shares) public {
        shares -= _shares;
    }

    function addUnderlyingStrategyShares(uint256 _underlyingStrategyShares) public {
        underlyingStrategyShares += _underlyingStrategyShares;
    }

    function removeUnderlyingStrategyShares(uint256 _underlyingStrategyShares) public {
        underlyingStrategyShares -= _underlyingStrategyShares;
    }
}
