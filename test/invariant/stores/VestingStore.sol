// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract VestingStore {
    struct Vesting {
        uint256 start;
        uint256 amount;
        uint256 previousLockedProfit;
    }

    Vesting[] public vestings;

    function addVesting(uint256 start, uint256 amount, uint256 previousLockedProfit) public {
        vestings.push(Vesting(start, amount, previousLockedProfit));
    }

    function getVestings() public view returns (Vesting[] memory) {
        return vestings;
    }
}
