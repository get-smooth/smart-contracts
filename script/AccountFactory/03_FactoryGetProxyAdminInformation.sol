// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "../Base.s.sol";
import { ProxyAdmin } from "src/v1/Proxy/TransparentProxy.sol";

bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

/// @title  FactoryGetProxyAdminInformation
/// @notice Fetch the proxy admin and the owner of the proxy admin
contract FactoryGetProxyAdminInformation is BaseScript {
    function run() public broadcast returns (address proxyAdmin, address proxyOwner) {
        // 1. check the factory implementation is valid
        address payable factoryInstance = payable(vm.envAddress("FACTORY_INSTANCE"));
        require(address(factoryInstance).code.length > 0, "Factory implem' not deployed");

        // 2. fetch the proxy admin
        proxyAdmin = abi.decode(abi.encodePacked(vm.load(factoryInstance, ADMIN_SLOT)), (address));

        // 3. fetch the proxy owner
        proxyOwner = ProxyAdmin(proxyAdmin).owner();
    }
}
