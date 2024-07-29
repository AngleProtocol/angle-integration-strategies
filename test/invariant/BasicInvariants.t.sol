// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import { UserActor } from "./actors/User.t.sol";
import { KeeperActor } from "./actors/Keeper.t.sol";
import { ParamActor } from "./actors/Param.t.sol";
import { MockRouter } from "../mock/MockRouter.sol";
import "../ERC4626StrategyTest.t.sol";

contract BasicInvariants is ERC4626StrategyTest {
    uint256 internal constant _NUM_USER = 10;
    uint256 internal constant _NUM_KEEPER = 2;
    uint256 internal constant _NUM_PARAM = 5;

    UserActor internal _userHandler;
    KeeperActor internal _keeperHandler;
    ParamActor internal _paramHandler;

    function setUp() public virtual override {
        super.setUp();

        // Switch to mock router
        MockRouter router = new MockRouter();
        vm.startPrank(developer);
        strategy.setTokenTransferAddress(address(router));
        strategy.setSwapRouter(address(router));
        vm.stopPrank();

        // Create actors
        _userHandler = new UserActor(_NUM_USER, address(strategy));
        _keeperHandler = new KeeperActor(_NUM_KEEPER, address(strategy));
        _paramHandler = new ParamActor(_NUM_PARAM, address(strategy));

        // Label newly created addresses
        for (uint256 i; i < _NUM_USER; i++) {
            vm.label(_userHandler.actors(i), string.concat("User ", vm.toString(i)));
        }
        vm.startPrank(developer);
        for (uint256 i; i < _NUM_KEEPER; i++) {
            strategy.grantRole(strategy.KEEPER_ROLE(), _keeperHandler.actors(i));
            vm.label(_keeperHandler.actors(i), string.concat("Keeper ", vm.toString(i)));
        }
        vm.stopPrank();
        for (uint256 i; i < _NUM_PARAM; i++) {
            vm.label(_paramHandler.actors(i), string.concat("Param ", vm.toString(i)));
        }

        targetContract(address(_userHandler));
        targetContract(address(_keeperHandler));
        targetContract(address(_paramHandler));

        {
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = KeeperActor.swap.selector;
            selectors[1] = KeeperActor.accumulate.selector;
            targetSelector(FuzzSelector({ addr: address(_keeperHandler), selectors: selectors }));
        }
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = ParamActor.warp.selector;
            targetSelector(FuzzSelector({ addr: address(_paramHandler), selectors: selectors }));
        }
        {
            bytes4[] memory selectors = new bytes4[](4);
            selectors[0] = UserActor.deposit.selector;
            selectors[1] = UserActor.withdraw.selector;
            selectors[2] = UserActor.redeem.selector;
            selectors[3] = UserActor.withdraw.selector;
            targetSelector(FuzzSelector({ addr: address(_userHandler), selectors: selectors }));
        }
    }

    function invariant_XXXXX() public {}
}
