// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";

/// @title Wrapper of the AccountFactory contract that exposes internal methods
/// @notice This contract is only intended to be used for testing purposes
/// @dev Keep in mind this wrapper adds extra cost to the gas consumption, only use it for
/// testing internal methods
contract AccountFactoryTestWrapper is AccountFactory {
    constructor(
        address entryPoint,
        address webAuthnVerifier,
        address _nameServiceOwner
    )
        AccountFactory(entryPoint, webAuthnVerifier, _nameServiceOwner)
    { }

    function isNameServiceSignatureLegit(bytes32 hash, bytes calldata signature) external view returns (bool) {
        return _isNameServiceSignatureLegit(hash, signature);
    }

    function checkAccountExistence(bytes32 loginHash) external view returns (address) {
        return _checkAccountExistence(loginHash);
    }
}
