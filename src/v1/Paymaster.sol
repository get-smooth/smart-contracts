// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BasePaymaster, Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { UserOperation } from "@eth-infinitism/interfaces/UserOperation.sol";
import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import "src/utils/Signature.sol" as Signature;
import { Metadata } from "src/v1/Metadata.sol";

/// @title  Paymaster
/// @notice Simple Paymaster contract that sponsors an user operation if the signature is signed by the operator
///
///         Here's some important design choices to acknowledge:
///         - The operator is in charge of signing the paymaster signature. He is the one that can sponsor an userOp
///         - The operator can be changed by the owner of the contract or the operator itself
///         - Only the owner is allowed to withdraw the funds deposited in the entrypoint and manage the staking
///         - We do not use the maxCost parameter meaning we do not check the maximum cost of the transaction
///         - We never return a context from the `_validatePaymasterUserOp` function, meaning the `_postOp` function
///           will never be called by the entrypoint
///         - The entrypoint is set in the constructor and cannot be changed.
///         - This contract is not upgradeable
///         - The signature includes the sender, nonce, chainId, the address of this contract and the callData to prevent
///           replay attacks
/// @custom:experimental This contract is unaudited yet
contract Paymaster is BasePaymaster {
    // ==============================
    // =========== STATE ============
    // ==============================

    address public operator;

    // ==============================
    // ======= EVENTS/ERRORS ========
    // ==============================

    error InvalidOperator();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @notice Set the owner, the operator and the address of the entrypoint.
    /// @param entryPoint The address of the entrypoint contract
    /// @param entryPoint The address of the owner. It can withdraw and stake the funds
    /// @param _operator The operator that will sign the paymaster signature
    constructor(
        address entryPoint,
        address owner,
        address _operator
    )
        BasePaymaster(IEntryPoint(entryPoint))
        Ownable(owner)
    {
        if (_operator == address(0)) {
            revert InvalidOperator();
        }

        operator = _operator;
    }

    // ==============================
    // ========= MODIFIER ===========
    // ==============================

    /// @notice Modifier to check if the sender is the owner or the operator
    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner() && msg.sender != operator) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    // ==============================
    // ======== FUNCTIONS ===========
    // ==============================

    /// @notice This function returns the version of the contract
    /// @return * The version of the contract
    function version() external pure virtual returns (uint256) {
        return Metadata.VERSION;
    }

    /// @notice Change the operator of the paymaster
    /// @param newOperator The new operator address
    /// @dev Only the owner or the operator can call this function
    function transferOperator(address newOperator) external onlyOwnerOrOperator {
        if (newOperator == address(0)) revert InvalidOperator();
        operator = newOperator;
    }

    /// @notice Allow the operator or the owner to withdraw for the owner
    /// @param amount The amount to withdraw
    /// @dev The owner has the ability to withdraw the funds to any address using the other withdrawTo function
    ///      `withdrawTo(address payable, uint256)`. The operator can only call this function
    function withdrawTo(uint256 amount) public onlyOwnerOrOperator {
        entryPoint.withdrawTo(payable(owner()), amount);
    }

    /// @notice Validates a paymaster user operation and calculates the required token amount for the transaction.
    /// @dev    This function do not use the maxCost parameter meaning we do not check the maximum cost of the
    ///         transaction.
    /// @param  userOp The user operation data.
    /// @param  {userOpHash} The hash of the user operation data. Not used in this implementation.
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

        // try recover the signature and return whether the paymaster accepts or refuses the sponsor
        validationData = Signature.recover(operator, message, userOp.paymasterAndData[20:])
            ? Signature.State.SUCCESS
            : Signature.State.FAILURE;
    }

    /// @notice Not used in this implementation.
    /// @dev    As we never return a context from the `_validatePaymasterUserOp` function, this function will
    ///         never be called by the entrypoint. This function can be useful in scenarios where the paymaster
    ///         needs to perform some checks after the sponsorised execution of the account.
    function _postOp(PostOpMode, bytes calldata, uint256) internal pure override {
        return;
    }
}
