// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { ERC4626, IERC20, ERC20 } from "oz/token/ERC20/extensions/ERC4626.sol";
import { AccessControl } from "oz/access/AccessControl.sol";
import { SafeERC20 } from "oz/token/ERC20/utils/SafeERC20.sol";
import "./utils/Errors.sol";

abstract contract BaseStrategy is ERC4626, AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Event emitted when the swap router is updated
     */
    event SwapRouterUpdated(address newSwapRouter);
    /**
     *  @notice Event emitted when the token proxy is updated
     */
    event TokenTransferAddressUpdated(address newTokenTransferAddress);
    /**
     *  @notice Event emitted when the performance fee is updated
     */
    event PerformanceFeeUpdated(uint256 newPerformanceFee);
    /**
     *  @notice Event emitted when the integrator fee recipient is updated
     */
    event IntegratorFeeRecipientUpdated(address newIntegratorFeeRecipient);
    /**
     *  @notice Event emitted when the protocol fee recipient is updated
     */
    event ProtocolFeeRecipientUpdated(address newProtocolFeeRecipient);
    /**
     *  @notice Event emitted when the vesting period is updated
     */
    event VestingPeriodUpdated(uint256 newVestingPeriod);

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier noOutgoingAssets() {
        uint256 assetBalance = IERC20(asset()).balanceOf(address(this));
        uint256 strategyAssetBalance = IERC20(strategyAsset).balanceOf(address(this));
        _;
        if (
            IERC20(asset()).balanceOf(address(this)) > assetBalance ||
            IERC20(strategyAsset).balanceOf(address(this)) > strategyAssetBalance
        ) {
            revert OutgoingAssets();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant INTEGRATOR_ROLE = keccak256("INTEGRATOR_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    uint256 public constant MAX_BPS = 100_000; // 100%

    /**
     * @notice The protocol fee taken from the performance fee
     */
    uint256 public immutable protocolFee;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The profit that is locked in the strategy
     */
    uint256 public vestingProfit;
    /**
     * @notice The last time the profit was updated
     */
    uint256 public lastUpdate;
    /**
     * @notice The vesting period for the profit
     */
    uint256 public vestingPeriod;

    /**
     * @notice The address of the strategy asset (stUSD for example)
     */
    address public immutable strategyAsset;
    /**
     * @notice The performance fee taken from the harvested profits from the strategy
     */
    uint256 public performanceFee;
    /**
     * @notice The address that receives the performance fee minus the protocol fee
     */
    address public integratorFeeRecipient;
    /**
     * @notice The address that receives the protocol fee from the performance fee
     */
    address public protocolFeeRecipient;

    /**
     *  @notice Dex/aggregaor router to call to perform swaps
     */
    address public swapRouter;
    /**
     * @notice Address to allow to swap tokens
     */
    address public tokenTransferAddress;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 initialPerformanceFee,
        address initialIntegratorFeeRecipient,
        address initialProtocolFeeRecipient,
        address initialAdmin,
        address initialSwapRouter,
        address initialTokenTransferAddress,
        string memory definitiveName,
        string memory definitiveSymbol,
        address definitiveAsset,
        address definitiveStrategyAsset,
        uint256 definitiveProtocolFee
    ) ERC20(definitiveName, definitiveSymbol) ERC4626(IERC20(definitiveAsset)) {
        if (initialPerformanceFee > MAX_BPS || definitiveProtocolFee > MAX_BPS) {
            revert InvalidFee();
        }
        if (
            initialIntegratorFeeRecipient == address(0) ||
            initialProtocolFeeRecipient == address(0) ||
            initialSwapRouter == address(0) ||
            initialTokenTransferAddress == address(0) ||
            definitiveStrategyAsset == address(0)
        ) {
            revert ZeroAddress();
        }

        performanceFee = initialPerformanceFee;
        protocolFee = definitiveProtocolFee;
        integratorFeeRecipient = initialIntegratorFeeRecipient;
        protocolFeeRecipient = initialProtocolFeeRecipient;
        swapRouter = initialSwapRouter;
        tokenTransferAddress = initialTokenTransferAddress;
        strategyAsset = definitiveStrategyAsset;

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            HELPERS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the current amount of locked profit
     * @dev This function is what effectively vests profits made by the protocol
     * @return The amount of locked profit
     */
    function lockedProfit() public view virtual returns (uint256) {
        // Get the last update and vesting delay.
        uint256 _lastUpdate = lastUpdate;
        uint256 _vestingPeriod = vestingPeriod;

        unchecked {
            // If the vesting period has passed, there is no locked profit.
            // This cannot overflow on human timescales
            if (block.timestamp >= _lastUpdate + _vestingPeriod) return 0;

            // Get the maximum amount we could return.
            uint256 currentlyVestingProfit = vestingProfit;

            // Compute how much profit remains locked based on the last time a profit was acknowledged and the vesting period
            // It's impossible for an update to be in the future, so this will never underflow.
            return currentlyVestingProfit - (currentlyVestingProfit * (block.timestamp - _lastUpdate)) / _vestingPeriod;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Harvest external rewards
     * @param data bytes to pass to the harvest function
     */
    function harvest(bytes calldata data) public onlyRole(KEEPER_ROLE) {
        _harvestRewards(data);
    }

    /**
     * @notice Deposits rewards directly rewards onto the contract
     * @param amount The amount of asset to deposit
     * @param transfer Whether to transfer the asset from the caller
     */
    function notifyRewardAmount(uint256 amount, bool transfer) public {
        if (transfer) {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        } else if (IERC20(asset()).balanceOf(address(this)) < amount) {
            revert InsufficientBalance();
        }

        _handleUserGain(amount);
    }

    /**
     * @notice  Updates the profit and loss made on the underlying strategy
     */
    function accumulate() public {}

    /**
     * @notice Propagates a user side gain
     * @param gain Gain to propagate
     */
    function _handleUserGain(uint256 gain) internal virtual {
        if (gain != 0) {
            vestingProfit = (lockedProfit() + gain);
            lastUpdate = block.timestamp;
        }
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the vesting period for the profit
     * @param newVestingPeriod The new vesting period to set
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setVestingPeriod(uint256 newVestingPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newVestingPeriod == 0 || newVestingPeriod > 365 days) revert InvalidParameter();

        vestingPeriod = newVestingPeriod;

        emit VestingPeriodUpdated(newVestingPeriod);
    }

    /**
     * @notice Set the performance fee for the strategy
     * @param newPerformanceFee The new performance fee to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setPerformanceFee(uint256 newPerformanceFee) external onlyRole(INTEGRATOR_ROLE) {
        if (newPerformanceFee > MAX_BPS) {
            revert InvalidFee();
        }
        performanceFee = newPerformanceFee;

        emit PerformanceFeeUpdated(newPerformanceFee);
    }

    /**
     * @notice Set the integrator fee recipient
     * @param newIntegratorFeeRecipient The new integrator fee recipient to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setIntegratorFeeRecipient(address newIntegratorFeeRecipient) external onlyRole(INTEGRATOR_ROLE) {
        if (newIntegratorFeeRecipient == address(0)) {
            revert ZeroAddress();
        }
        integratorFeeRecipient = newIntegratorFeeRecipient;

        emit IntegratorFeeRecipientUpdated(newIntegratorFeeRecipient);
    }

    /**
     * @notice Set the protocol fee recipient
     * @param newProtocolFeeRecipient The new protocol fee recipient to set
     * @custom:requires PROTOCOL_ROLE
     */
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyRole(PROTOCOL_ROLE) {
        if (newProtocolFeeRecipient == address(0)) {
            revert ZeroAddress();
        }
        protocolFeeRecipient = newProtocolFeeRecipient;

        emit ProtocolFeeRecipientUpdated(newProtocolFeeRecipient);
    }

    /**
     * @notice Set the dex/aggregator router to call to perform swaps
     * @param newSwapRouter address of the router
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setSwapRouter(address newSwapRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSwapRouter == address(0)) revert ZeroAddress();

        swapRouter = newSwapRouter;

        emit SwapRouterUpdated(newSwapRouter);
    }

    /**
     * @notice Set the token proxy address to allow to swap tokens
     * @param newTokenTransferAddress address of the token proxy
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setTokenTransferAddress(address newTokenTransferAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTokenTransferAddress == address(0)) revert ZeroAddress();

        tokenTransferAddress = newTokenTransferAddress;

        emit TokenTransferAddressUpdated(newTokenTransferAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Swap tokens using the router/aggregator
     * @param tokens array of tokens to swap
     * @param callDatas array of bytes to call the router/aggregator
     * @custom:requires KEEPER_ROLE
     */
    function swap(address[] calldata tokens, bytes[] calldata callDatas) public onlyRole(KEEPER_ROLE) noOutgoingAssets {
        _swap(tokens, callDatas);
    }

    /**
     * @notice Swap tokens using the router/aggregator
     * @param tokens array of tokens to swap
     * @param callDatas array of bytes to call the router/aggregator
     */
    function _swap(address[] calldata tokens, bytes[] calldata callDatas) internal {
        uint256 length = tokens.length;
        for (uint256 i; i < length; ++i) {
            _approveTokenIfNeeded(tokens[i], tokenTransferAddress);
            _performRouterSwap(callDatas[i]);
        }
    }

    /**
     * @notice Perform the swap using the router/aggregator
     * @param callData bytes to call the router/aggregator
     */
    function _performRouterSwap(bytes calldata callData) internal {
        (bool success, bytes memory retData) = swapRouter.call(callData);

        if (!success) {
            if (retData.length != 0) {
                assembly {
                    revert(add(32, retData), mload(retData))
                }
            }
            revert SwapError();
        }
    }

    /**
     * @notice Approve the router/aggregator to spend the token if needed
     * @param _token address of the token to approve
     * @param _spender address of the router/aggregator
     */
    function _approveTokenIfNeeded(address _token, address _spender) internal {
        if (ERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).approve(_spender, type(uint256).max);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim external rewards
     */
    function _harvestRewards(bytes calldata data) internal virtual;

    /**
     * @notice Compute the amount of asset that can be deposited
     * @return amount of asset that can be deposited
     */
    function _depositable() internal view virtual returns (uint256);

    /**
     * @notice Compute the amount of asset that can be withdrawn
     * @return amount of asset that can be withdrawn
     */
    function _withdrawable() internal view virtual returns (uint256);

    /**
     * @notice Compute the amount of asset held in the strategy contract
     * @return amount of asset held in the strategy contract
     */
    function _assetsHeld() internal view virtual returns (uint256);
}
