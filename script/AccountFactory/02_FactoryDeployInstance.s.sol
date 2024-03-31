// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";
import { TransparentUpgradeableProxy } from "src/v1/Proxy/TransparentProxy.sol";

bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

/// @title  FactoryDeployInstance
/// @notice Deploy an instance of the account factory
contract FactoryDeployInstance is BaseScript {
    function run() public broadcast returns (AccountFactory accountFactory, address proxyAdmin) {
        // 1. check the proxy owner is valid
        address proxyOwner = vm.envAddress("PROXY_OWNER");
        require(proxyOwner != address(0), "Invalid owner address");

        // 2. check the factory signer is valid
        address factorySigner = vm.envAddress("FACTORY_SIGNER");
        require(factorySigner != address(0), "Invalid factory signer address");

        // 3. check the factory implementation is valid
        address payable factoryImplementation = payable(vm.envAddress("FACTORY_IMPLEMENTATION"));
        require(address(factoryImplementation).code.length > 0, "Factory implem' not deployed");

        // 4. Deploy a instance of the factory
        accountFactory = AccountFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImplementation,
                    proxyOwner,
                    abi.encodeWithSelector(AccountFactory.initialize.selector, factorySigner)
                )
            )
        );

        // 5. fetch the proxy admin
        proxyAdmin = abi.decode(abi.encodePacked(vm.load(address(accountFactory), ADMIN_SLOT)), (address));
    }
}
