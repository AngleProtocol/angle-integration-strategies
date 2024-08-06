// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { ERC20 } from "oz/token/ERC20/ERC20.sol";
import { console } from "forge-std/console.sol";
import { ERC4626Strategy } from "../contracts/ERC4626Strategy.sol";

contract DepositPayloadScript is Script {
    ERC4626Strategy stUSDStrat;
    address ROUTER_ADDRESS;

    function setUp() public {}

    function run(
        bytes calldata data,
        address inputTokenAddress,
        uint256 inputTokenAmount,
        address strategyAddress,
        address routerAddress
    ) external {
        // Start broadcasting transactions
        vm.startBroadcast();

        ROUTER_ADDRESS = routerAddress;
        stUSDStrat = ERC4626Strategy(strategyAddress);

        // Allowance
        ERC20 tokenToSwap = ERC20(inputTokenAddress);
        tokenToSwap.approve(ROUTER_ADDRESS, inputTokenAmount);

        // Deposit - Call mixer() function
        (bool success, ) = ROUTER_ADDRESS.call(data);
        require(success, "Deposit - mixer() call failed");

        vm.stopBroadcast();
    }
}
