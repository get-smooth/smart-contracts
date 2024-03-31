// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { TransparentUpgradeableProxy } from "src/v1/Proxy/TransparentProxy.sol";

/// @title BaseTestDeployment
/// @notice Utility contract to deploy our contracts for testing purposes
contract BaseTestDeployment {
    /// @notice Deploy an AccountFactory implementation
    /// @dev The account implementation is the contract that will be deployed when creating an account
    /// @param accountImplementation The address of the account implementation. Immutable in the factory implementation
    /// @return AccountFactory The deployed AccountFactory implementation
    function deployFactoryImplementation(address accountImplementation) internal returns (AccountFactory) {
        return new AccountFactory(accountImplementation);
    }

    /// @notice Deploy an AccountFactory instance
    /// @dev TransparentUpgradeableProxy that points to the factory implementation
    /// @param factoryImplementation The address of the factory implementation
    /// @param proxyOwner The owner of the proxy
    /// @param factorySigner The signer of the factory. This is the address expected to sign the deployment signature
    /// @return AccountFactory The deployed AccountFactory instance
    function deployFactoryInstance(
        address factoryImplementation,
        address proxyOwner,
        address factorySigner
    )
        internal
        returns (AccountFactory)
    {
        return AccountFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImplementation,
                    proxyOwner,
                    abi.encodeWithSelector(AccountFactory.initialize.selector, factorySigner)
                )
            )
        );
    }
}
