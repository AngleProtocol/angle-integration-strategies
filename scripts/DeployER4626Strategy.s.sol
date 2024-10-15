// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import { ERC4626Strategy, BaseStrategy } from "../contracts/ERC4626Strategy.sol";
import "utils/src/CommonUtils.sol";
import "../test/Constants.t.sol";
import "forge-std/Script.sol";

contract DeployERC4626Strategy is Script, CommonUtils {
    function run() external {
        uint256 chainId = CHAIN_SOURCE;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployer);

        /** TODO  complete */
        address asset = _chainToContract(chainId, ContractType.AgUSD);
        // address strategyAsset = _chainToContract(chainId, ContractType.StUSD);
        address strategyAsset = 0x125D41A6e5dbf455cD9Df8F80BCC6fd172D52Cc6;

        address integrator = 0xcccc68b4aCf30A020A25D25Bc2Cc0ab96C80c9FC;
        address developer = _chainToContract(chainId, ContractType.GuardianMultisig);
        address keeper = 0xa9bbbDDe822789F123667044443dc7001fb43C01;

        uint32 performanceFee = 1_500; // 15%
        uint32 developerFee = 0; // 0%
        uint64 vestingPeriod = 0 weeks; // no vesting on stUSD as not playable

        string memory name = "USDA Morpho Gauntlet Strategy Trust Wallet";
        string memory symbol = "USDA-MG-TW";
        /** END  complete */

        ERC4626Strategy strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                performanceFee,
                developerFee,
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                vestingPeriod,
                name,
                symbol,
                asset,
                strategyAsset
            )
        );
        console.log("Strategy address: ", address(strategy));

        vm.stopBroadcast();
    }
}
