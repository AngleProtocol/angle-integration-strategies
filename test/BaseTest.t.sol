// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "utils/src/CommonUtils.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract BaseTest is Test, CommonUtils {
    // Useful addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public integrator = makeAddr("integrator");
    address public keeper = makeAddr("keeper");
    address public developer = makeAddr("developer");

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(integrator, "integrator");
        vm.label(keeper, "keeper");
        vm.label(developer, "developer");
    }
}
