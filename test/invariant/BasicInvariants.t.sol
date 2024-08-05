// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import { UserActor } from "./actors/User.t.sol";
import { KeeperActor } from "./actors/Keeper.t.sol";
import { ParamActor } from "./actors/Param.t.sol";
import { MockRouter } from "../mock/MockRouter.sol";
import { VestingStore } from "./stores/VestingStore.sol";
import { StateVariableStore } from "./stores/StateVariableStore.sol";
import "../ERC4626StrategyTest.t.sol";

contract BasicInvariants is ERC4626StrategyTest {
    using UtilsLib for uint256;

    uint256 internal constant _NUM_USER = 10;
    uint256 internal constant _NUM_KEEPER = 2;
    uint256 internal constant _NUM_PARAM = 5;

    UserActor internal _userHandler;
    KeeperActor internal _keeperHandler;
    ParamActor internal _paramHandler;
    VestingStore internal _vestingStore;
    StateVariableStore internal _stateVariableStore;

    // state variables
    uint256 internal _previousDeveloperShares;
    uint256 internal _previousIntegratorShares;

    function setUp() public virtual override {
        super.setUp();

        // Switch to mock router
        MockRouter router = new MockRouter();
        vm.startPrank(developer);
        strategy.setTokenTransferAddress(address(router));
        strategy.setSwapRouter(address(router));
        vm.stopPrank();
        deal(asset, address(router), 1e27);

        // Deposit some assets
        vm.startPrank(alice);
        deal(asset, alice, 1e18);
        IERC20(asset).approve(address(strategy), 1e18);
        strategy.deposit(1e18, alice);
        vm.stopPrank();

        // Create stores
        _vestingStore = new VestingStore();
        _stateVariableStore = new StateVariableStore();

        _stateVariableStore.addShares(1e18);
        _stateVariableStore.addUnderlyingStrategyShares(ERC4626(strategyAsset).convertToShares(1e18));

        // Create actors
        _userHandler = new UserActor(_NUM_USER, address(strategy), _stateVariableStore);
        _keeperHandler = new KeeperActor(_NUM_KEEPER, address(strategy), _stateVariableStore, _vestingStore);
        _paramHandler = new ParamActor(_NUM_PARAM, address(strategy));

        // Label newly created addresses
        for (uint256 i; i < _NUM_USER; i++) {
            vm.label(_userHandler.actors(i), string.concat("User ", vm.toString(i)));
            deal(asset, _userHandler.actors(i), 1e27);
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

    function invariant_CorrectVesting() public {
        VestingStore.Vesting[] memory vestings = _vestingStore.getVestings();
        uint256 totalAmount;
        for (uint256 i; i < vestings.length; i++) {
            if (block.timestamp >= vestings[i].start + strategy.vestingPeriod()) {
                totalAmount = 0;
            } else {
                uint256 nextTimestamp = i + 1 < vestings.length ? vestings[i + 1].start : block.timestamp;
                uint256 amount = vestings[i].amount + vestings[i].previousLockedProfit;
                totalAmount = amount - (amount * (nextTimestamp - vestings[i].start)) / strategy.vestingPeriod();
            }
        }
        uint256 strategyBalance = ERC4626(strategyAsset).balanceOf(address(strategy));
        assertApproxEqAbs(strategy.lockedProfit(), totalAmount, 1);
        assertApproxEqAbs(
            strategy.totalAssets(),
            ERC4626(strategyAsset).convertToAssets(strategyBalance).zeroFloorSub(totalAmount),
            1
        );
    }

    function invariant_FeeRecipientNoBurn() public {
        assertGe(strategy.balanceOf(strategy.integratorFeeRecipient()), _previousIntegratorShares);
        assertGe(strategy.balanceOf(strategy.developerFeeRecipient()), _previousDeveloperShares);

        _previousIntegratorShares = strategy.balanceOf(strategy.integratorFeeRecipient());
        _previousDeveloperShares = strategy.balanceOf(strategy.developerFeeRecipient());
    }

    function invariant_CorrectTotalSupply() public {
        assertEq(strategy.totalSupply(), _stateVariableStore.shares());
    }

    function invariant_CorrectTotalAssets() public {
        assertApproxEqRel(
            strategy.totalAssets(),
            ERC4626(strategyAsset).convertToAssets(_stateVariableStore.underlyingStrategyShares()) -
                strategy.lockedProfit(),
            10
        );
        assertApproxEqRel(
            _stateVariableStore.underlyingStrategyShares(),
            ERC4626(strategyAsset).balanceOf(address(strategy)),
            10
        );
    }
}
