// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;
import { Account } from "./Account.sol";

contract AccountFactory {
    address public immutable accountImplementation;
    address public immutable nameServiceOwner;

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
    constructor(address entryPoint, address webAuthnVerifier, address _nameServiceOwner) {
        nameServiceOwner = _nameServiceOwner;
        accountImplementation = address(new Account(entryPoint, webAuthnVerifier, _nameServiceOwner));
    }

}
