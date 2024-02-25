// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { UserOperation } from "@eth-infinitism/interfaces/UserOperation.sol";
import { BaseAccount } from "@eth-infinitism/core/BaseAccount.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";
import { SignerVaultWebAuthnP256R1 } from "src/SignerVaultWebAuthnP256R1.sol";
import { AccountFactory } from "src/AccountFactory.sol";
import "src/utils/Signature.sol" as Signature;

contract Account is Initializable, BaseAccount {
    // ==============================
    // ========= CONSTANTS ==========
    // ==============================

    address public immutable webAuthnVerifier;
    /// @notice This variable is exposed by the `entryPoint` method
    address internal immutable entryPointAddress;
    address internal immutable factory;

    /// @notice Return the entrypoint used by this implementation
    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(entryPointAddress);
    }

    // ==============================
    // ========== EVENTS ============
    // ==============================

    /// @notice Emitted every time a signer is added to the account
    /// @dev The credIdHash is indexed to allow off-chain services to track account with same signer authorized
    event SignerAdded(bytes32 indexed credIdHash, uint256 pubkeyX, uint256 pubkeyY);

    // ==============================
    // ========== ERRORS ============
    // ==============================

    /// @notice This error is thrown if `firstSignerFuse` is set to false. That can happen if:
    ///         - `addFirstSigner` is called before calling the `initialize` function
    ///         - `firstSignerFuse` has already been called in the past
    error FirstSignerAlreadySet();
    error NotTheFactory();
    /// @notice This error is thrown if arguments passed to the `executeBatch` function are not of the same length
    /// @dev    `values` can be of length 0 if no value is passed to the calls
    error IncorrectExecutionBatchParameters();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @notice Called by the factory at construction time when it deploys the account
    /// @dev    Do not store any state in this function as the contract will be proxified, only immutable variables
    /// @param _entryPoint The address of the 4337 entrypoint used by this implementation
    /// @param _webAuthnVerifier The address of the webauthn library used for verify the webauthn signature
    constructor(address _entryPoint, address _webAuthnVerifier) {
        entryPointAddress = _entryPoint;
        webAuthnVerifier = _webAuthnVerifier;

        // address of the factory that deployed this contract.
        // only the factory will have the ability to set the first signer later on
        factory = msg.sender;
    }

    /// @notice Called once during the creation of the instance. Set the fuse that gates the assignment of the first
    ///         signer to true. The first signer can then be stored by calling the `addFirstSigner` function.
    ///         The `initializer` modifier prevents the function to be called twice during its lifetime
    function initialize() external reinitializer(1) {
        bytes32 slot = StorageSlotRegistry.FIRST_SIGNER_FUSE;

        // toggle the fuse to allow the storing of the first signer by calling `addFirstSigner`
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
    }

    // ==============================
    // ======== FUNCTIONS ===========
    // ==============================

    /// @notice Allow the contract to receive native tokens
    // solhint-disable-next-line no-empty-blocks
    receive() external payable { }

    /// @notice This modifier check if the fuse has already been burnt and revert the transaction if it is the case
    ///         if the fuse has not been burnt yet, it burns it and allow the function to be called
    /// @dev    The fuse is stored at the slot given by the constant `StorageSlotRegistry.FIRST_SIGNER_FUSE`
    modifier singleUseLock() {
        bytes32 slotFirstSignerFuse = StorageSlotRegistry.FIRST_SIGNER_FUSE;
        bool currentFuseValue;

        // check the value of the fusƒe variable
        assembly ("memory-safe") {
            currentFuseValue := sload(slotFirstSignerFuse)
        }

        // if the fuse has already been burnt (set to false), revert the transaction
        if (currentFuseValue == false) revert FirstSignerAlreadySet();

        // burn the fuse to prevent this function to be called again in the future
        assembly ("memory-safe") {
            sstore(slotFirstSignerFuse, 0)
        }

        // continue the execution of the function
        _;
    }

    /// @notice This modifier ensure the caller is the factory that deployed this contract
    modifier onlyFactory() {
        if (msg.sender != factory) revert NotTheFactory();
        _;
    }

    /// @notice This modifier ensure the caller is the 4337 entrypoint stored
    modifier onlyEntrypoint() {
        _requireFromEntryPoint();
        _;
    }

    /// @notice Add the first signer to the account. This function is only call once by the factory
    ///         during the deployment of the account. All the future signers must be added using the
    ///         `addSigner` function.
    /// @dev    This function is expected to add a signer generated using the WebAuthn protocol on the
    ///         secp256r1 curve. Adding another type of signer as the first signer is not supported yet.
    ///         As the call of this function is expected to be wrapped in the same transaction than a
    ///         interaction with the account, we do not check webauthn's payload yet.
    ///         The payload is automatically check in the execution function meaning if the payload
    ///         is incorrect or do not correspond to the signer stored in this function, the whole tx
    ///         will revert (reverting de facto the signer stored in this function).
    ///         The `singleUseLock` modifier prevents this function to be called twice during its lifetime
    ///         The `onlyFactory` modifier ensures only the factory can call this function
    /// @param  pubkeyX The X coordinate of the signer's public key.
    /// @param  pubkeyY The Y coordinate of the signer's public key.
    /// @param  credIdHash The hash of the credential ID associated to the signer
    function addFirstSigner(uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) external onlyFactory singleUseLock {
        // add account's first signer and emit the signer addition event
        SignerVaultWebAuthnP256R1.set(credIdHash, pubkeyX, pubkeyY);
        emit SignerAdded(credIdHash, pubkeyX, pubkeyY);
    }

    /// @notice Return a signer stored in the account using its credIdHash. When storing a signer, the credId
    ///         is hashed using keccak256 because its length is unpredictable. This function allows to
    ///         retrieve a signer using its credIdHash.
    /// @param  _credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function getSigner(bytes32 _credIdHash)
        external
        view
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (credIdHash, pubkeyX, pubkeyY) = SignerVaultWebAuthnP256R1.get(_credIdHash);
    }

    /// @notice Return a signer stored in the account using the raw version of the credId
    ///         (without hashing it).
    /// @dev    This function hashes the credId internally adding an extra cost to the call
    /// @param  credId The credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function getSigner(bytes memory credId)
        external
        view
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (credIdHash, pubkeyX, pubkeyY) = SignerVaultWebAuthnP256R1.get(credId);
    }

    /// @notice The validation of the creation signature
    /// @dev This creation signature is the signature that can only be used once during account creation (nonce == 0).
    ///      This signature is different from the ones the account will use for validation for the rest of its lifetime.
    ///      This signature is not a webauthn signature made on p256r1 but a traditional EIP-191 signature made on
    ///      p256k1 and signed by the owner of the factory to prove the account has been authorized for deployment
    ///      (== the username is available to be picked)
    /// @param initCode The initCode field presents in the userOp. It has been used to create the account
    /// @return 0 if the signature is valid, 1 otherwise
    function _validateCreationSignature(
        bytes calldata signature,
        bytes calldata initCode
    )
        internal
        view
        returns (uint256)
    {
        // 1. check that the nonce is 0x00. The value of the first key is checked here
        if (getNonce() != 0) return Signature.State.FAILURE;

        // 2. ensure the initCode is at least 152-bytes long
        if (initCode.length < 152) return Signature.State.FAILURE;

        // 3. get the data that composes the message from the initcode bytes (except the selector)
        // The initCode is composed of:
        //  - 20 bytes for the address of the factory used to deploy this account
        //  - 4 bytes for the selector of the factory function called  --NOT_USED--
        //  - 32 bytes for the X coordinate of the public key
        //  - 32 bytes for the Y coordinate of the public key
        //  - 32 bytes for the loginHash
        //  - 32 bytes for the credIdHash
        //  - X bytes for the signature --NOT_USED--
        //
        // Using bytes slicing instead of `abi.decode` works because all the simple types have been packed
        // at the beginning of the signature function that is called by the initCode. It would be necessary
        // to use `abi.decode` if we were interested of retrieving the signature (the last parameter of the factory's
        // function) because it is a dynamic type (1 word is used to store the address where the length is stored, 1
        // word is used to store the length and then the data is stored in the next words).
        // This technique is more gas efficient than using `abi.decode` because the signature is not copied in memory by
        // the compiler
        //
        // Note that any change in the factory's function signature will break the signature validation of this account!
        address userOpFactory = address(bytes20(initCode[:20]));
        uint256 pubKeyX = uint256(bytes32(initCode[24:56]));
        uint256 pubKeyY = uint256(bytes32(initCode[56:88]));
        bytes32 loginHash = bytes32(initCode[88:120]);
        bytes32 credIdHash = bytes32(initCode[120:152]);

        // 4. check the factory is the same than the one stored here
        if (userOpFactory != factory) return Signature.State.FAILURE;

        // 5. recreate the message and try to recover the signer
        bytes memory message = abi.encode(Signature.Type.CREATION, loginHash, pubKeyX, pubKeyY, credIdHash);

        // 6. fetch the expected signer from the factory contract
        address expectedSigner = AccountFactory(factory).admin();

        // 7. Check the signature is valid and revert if it is not
        if (Signature.recover(expectedSigner, message, signature) == false) return Signature.State.FAILURE;

        // 8. Check the signer is the same than the one stored by the factory during the account creation process
        (bytes32 $credIdHash, uint256 $pubkeyX, uint256 $pubkeyY) = SignerVaultWebAuthnP256R1.get(credIdHash);
        if ($credIdHash != credIdHash || $pubkeyX != pubKeyX || $pubkeyY != pubKeyY) return Signature.State.FAILURE;

        return Signature.State.SUCCESS;
    }

    /// @notice Validate the userOp signature
    /// @dev We do not return any time-range, only the signature validation
    /// @param userOp validate the userOp.signature field
    /// @param * convenient field: the hash of the request, to check the signature against
    /// @return validationData signature and time-range of this operation.
    ///         - 20 bytes: sigAuthorizer - 0 for valid signature, 1 to mark signature failure
    ///         - 06 bytes: validUntil - last timestamp this operation is valid. 0 for "indefinite"
    ///         - 06 bytes: validAfter - first timestamp this operation is valid
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 // userOpHash
    )
        internal
        view
        override
        returns (uint256 validationData)
    {
        // 1.a check the signature is a "webauthn p256r1" signature
        if (userOp.signature[0] == Signature.Type.WEBAUTHN_P256R1) {
            // TODO: verify the webauthn signature
        }

        // 1.b check the signature is a "creation" signature (length is checked by the signature library)
        if (userOp.signature[0] == Signature.Type.CREATION) {
            return _validateCreationSignature(userOp.signature, userOp.initCode);
        }

        return Signature.State.FAILURE;
    }

    // *********** EXECUTE ***********//

    /// @notice Execute a transaction
    /// @dev Revert if the call fails
    /// @param target The address of the contract to call
    /// @param value The value to pass in this call
    /// @param data The calldata to pass in this call (selector + encoded arguments)
    function _call(address target, uint256 value, bytes calldata data) internal {
        (bool success, bytes memory result) = target.call{ value: value }(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Execute a transaction if called by the entrypoint
    /// @dev Revert if the call fails
    /// @param target The address of the contract to call
    /// @param value The value to pass in this call
    /// @param data The calldata to pass in this call (selector + encoded arguments)
    function execute(address target, uint256 value, bytes calldata data) external onlyEntrypoint {
        _call(target, value, data);
    }

    /// @notice Execute a sequence of transactions if called by the entrypoint
    /// @dev Revert if one of the the calls fail. Parameters with the same index define the same tx
    /// @param targets The list of contracts to call
    /// @param values The list of value to pass to the calls. Can be zero-length for no-value calls
    /// @param datas The calldata to pass to the calls (selector + encoded arguments)
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    )
        external
        onlyEntrypoint
    {
        // 1. check the length of the parameters is correct. Note that `values` can be of length 0 if no value is passed
        if (targets.length != datas.length || (values.length != 0 && values.length != datas.length)) {
            revert IncorrectExecutionBatchParameters();
        }

        // 2. check if at least one value is passed to the calls
        bool isPayable = values.length != 0;
        uint256 nbOfTransactions = targets.length;

        // 3. execute the transactions
        for (uint256 i; i < nbOfTransactions;) {
            _call(targets[i], isPayable ? values[i] : 0, datas[i]);

            unchecked {
                ++i;
            }
        }
    }
}

// ==============================
// ========== STATE =============
// ==============================

// SLOT: `StorageSlotRegistry.FIRST_SIGNER_FUSE`
//  This variable is used to prevent the first signer to be added twice. Here's the expected lifecycle
//   - The slot points to the default value (0x00 = false) by default
//   - The value is set to true only once by the `initialize` function
//   - Then the value is set back to false while the `addFirstSigner` function is called
//
//   It is expected the `addFirstSigner` function is called in the same tx than the `initialize` function.
//   The `initialize` function can only be called once, meaning there is no way to set back the value to true
