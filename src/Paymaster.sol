// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BasePaymaster, Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { ECDSA } from "@openzeppelin/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { UserOperation } from "@eth-infinitism/interfaces/UserOperation.sol";
import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";

uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILURE = 1;

/// @dev Used to revert when someone try to change the admin of the contract. The admin is immutable
error OwnershipTransferNotAllowed();

// TODO: - Rewrite a custom implementation of BasePaymaster without using the Ownable dependency
/// @title  Paymaster
/// @notice Simple Paymaster contract that sponsors an user operation if the signature is signed by the admin
/// @dev    Here's some opinionated design decisions we made:
///         - The admin of the contract is immutable and set at the contract deployment. Each paymaster instance has an
///           unique admin address.
///         - The admin is in charge of signing the paymaster signature. He is the one that can sponsor an userOp
///         - We never access the storage of the contract to avoid stacking in the entrypoint contract
///         - We do not use the maxCost parameter meaning we do not check the maximum cost of the transaction
///         - We never return a context from the `_validatePaymasterUserOp` function, meaning the `_postOp` function
///           will never be called by the entrypoint
///         - The signature includes the sender, nonce, chainId, this address and the callData to prevent replay attacks
contract Paymaster is BasePaymaster {
    address private immutable admin;

    /// @notice Set the immutable admin of the contract and the entrypoint address. The admin is in charge of signing
    ///         the paymaster signature
    /// @dev    BasePaymaster inherit from Ownable that's why we need to call the Ownable constructor here
    ///         to set the admin of the contract in the storage. However, we decided to make the admin immutable
    ///         to avoid accessing the storage of the contract, that will force us to stack in the entrypoint contract.
    ///         In order to do that, we override the `owner` and `_transferOwnership` functions from the Ownable
    ///         contract to read the immutable data instead.
    /// @param entryPoint The address of the entrypoint contract
    /// @param _admin The address of the admin that will sign the paymaster signature
    constructor(address entryPoint, address _admin) BasePaymaster(IEntryPoint(entryPoint)) Ownable(_admin) {
        admin = _admin;
    }

    /// @notice Return the immutable admin of the contract
    /// @dev    This function is an override of the owner function from the Ownable contract.
    ///         This contract is developed in a way it must be impossible to change the admin
    ///         of the contract. The admin is set at the contract deployment and cannot be changed.
    ///         This is to avoid accessing the storage of the contract, that will force us to stack
    ///         in the entrypoint contract
    /// @return The immutable admin of the contract
    function owner() public view virtual override returns (address) {
        return admin;
    }

    /// @notice Revert if someone try to transfer the ownership of the contract
    function transferOwnership(address) public pure override {
        revert OwnershipTransferNotAllowed();
    }

    /// @notice Revert if someone try to renounce the ownership of the contract
    function renounceOwnership() public pure override {
        revert OwnershipTransferNotAllowed();
    }

    /// @notice Validates a paymaster user operation and calculates the required token amount for the transaction.
    /// @dev    This function do not use the maxCost parameter meaning we do not check the maximum cost of the
    ///         transaction.
    /// @param  userOp The user operation data.
    /// @param  {userOpHash} The hash of the user operation data.
    /// @param  {maxCost} The maximum cost of this transaction (based on maximum gas and gas price from userOp).
    ///         Not used in this implementation.
    /// @return context Value to send to a postOp. Zero length to signify postOp is not required.
    ///         Not used in this implementation.
    /// @return validationData A uint256 value indicating the result of the validation (0 or 1)
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, // useOpHash
        uint256 // maxCost
    )
        internal
        view
        override
        returns (bytes memory, uint256 validationData)
    {
        // Encoding the message with the sender, nonce, chainId, address of the paymaster and callData
        // - By including the sender, we prevent replay attacks across different senders.
        // - By including the nonce, we prevent replay attacks across different nonces.
        // - By including the chainId, we prevent replay attacks across different chains.
        // - By including the address of this contract, we prevent replay attacks across different paymasters.
        // - By including the callData, we only allow the paymaster to pay for a specific action.
        bytes memory message = abi.encode(userOp.sender, userOp.nonce, block.chainid, address(this), userOp.callData);
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // The first 20 bytes of the paymasterAndData is the address of the paymaster, the rest is the signature
        (address recoveredAddress, ECDSA.RecoverError error,) = ECDSA.tryRecover(hash, userOp.paymasterAndData[20:]);

        // return whether the paymaster accepts or refuses sponsorship of the user operation
        validationData =
            recoveredAddress == admin && error == ECDSA.RecoverError.NoError ? VALIDATION_SUCCESS : VALIDATION_FAILURE;
    }

    /// @notice Not used in this implementation.
    /// @dev    As we never return a context from the `_validatePaymasterUserOp` function, this function will
    ///         never be called by the entrypoint. This function can be useful in scenarios where the paymaster
    ///         needs to perform some checks after the sponsorised execution of the account.
    function _postOp(PostOpMode, bytes calldata, uint256) internal pure override {
        return;
    }
}
