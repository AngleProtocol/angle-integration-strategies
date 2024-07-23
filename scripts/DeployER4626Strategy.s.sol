// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { ERC4626Strategy, BaseStrategy } from "../contracts/ERC4626Strategy.sol";
import "utils/src/CommonUtils.sol";
import "../test/Constants.t.sol";
import "forge-std/Script.sol";

contract DeployERC4626Strategy is Script, CommonUtils {
    function run() external {
        uint256 chainId = CHAIN_SOURCE;
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);

        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployer);

        /** TODO  complete */
        address asset = _chainToContract(chainId, ContractType.AgUSD);
        address strategyAsset = _chainToContract(chainId, ContractType.StUSD);

        address integrator = _chainToContract(chainId, ContractType.GuardianMultisig);
        address developer = _chainToContract(chainId, ContractType.GuardianMultisig);
        address keeper = 0xa9bbbDDe822789F123667044443dc7001fb43C01;

        uint32 performanceFee = 10000; // 10%
        uint32 developerFee = 20000; // 20%

        string memory name = "stUSD Strategy";
        string memory symbol = "stUSDStrat";
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
                1 weeks,
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
