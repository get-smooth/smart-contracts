// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory, Account, ERC1967Proxy } from "./AccountFactory.sol";

/// @title  Multi-seps 4337-compliant Account Factory
/// @notice This contract inherits from the AccountFactory contract and adds a multi-steps scenario.
/// @custom:experimental This is an experimental contract.
contract AccountFactoryMultiSteps is AccountFactory {
    event AccountCreated(bytes32 loginHash, address account);

    /// @notice Deploy the implementation of the account and store its address in the storage of the factory. This
    ///         implementation will be used as the implementation reference
    ///         for all the proxies deployed by this factory.
    /// @param  entryPoint The unique address of the entrypoint (EIP-4337 related)
    /// @param  webAuthnVerifier The address of the crypto library that will be used by
    ///         the account to verify the WebAuthn signature of the signer(s)
    /// @param  _nameServiceOwner The address used to verify the signature of the name service.
    ///         This address is stored in the storage of this contract that validate future signatures
    /// @dev    The account deployed here is expected to be proxied later, its own storage won't be used.
    ///         All the arguments passed to the constructor function are used to set immutable variables.
    ///         As a valid signature from the nameServiceOwner is required to set the first signer of the account,
    ///         there is no need to make the account inoperable. No one will be able to use it.
    constructor(
        address entryPoint,
        address webAuthnVerifier,
        address _nameServiceOwner
    )
        AccountFactory(entryPoint, webAuthnVerifier, _nameServiceOwner)
    { }

    /// @notice This is the multi-steps scenario. This function either deploys an account or returns the address of
    ///         an existing account based on the parameter given. In any case this function set the first signer.
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @return The address of the account (either deployed or not)
    function createAccount(bytes32 loginHash) external returns (address) {
        // check if the account is already deployed and return prematurely if it is
        address alreadyDeployedAddress = _checkAccountExistence(loginHash);
        if (alreadyDeployedAddress != address(0)) {
            return alreadyDeployedAddress;
        }

        // deploy the proxy for the user. During the deployment call, the
        // initialize function in the implementation contract is called
        // using the `delegatecall` opcode
        Account account = Account(
            payable(
                new ERC1967Proxy{ salt: loginHash }(
                    address(accountImplementation), abi.encodeCall(Account.initialize, (loginHash))
                )
            )
        );

        emit AccountCreated(loginHash, address(account));

        return address(account);
    }
}
