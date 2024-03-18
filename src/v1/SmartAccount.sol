// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { UserOperation } from "@eth-infinitism/interfaces/UserOperation.sol";
import { BaseAccount } from "@eth-infinitism/core/BaseAccount.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import "src/utils/Signature.sol" as Signature;
import { IWebAuthn256r1 } from "@webauthn/IWebAuthn256r1.sol";
import { Metadata } from "src/v1/Metadata.sol";

// @DEV: MONO-SIGNER VERSION
/**
 * TODO:
 *  - Manage webauthn multi-signers
 *  - 4337 chore (postOp etc...)
 *  --- Take a look to proxy's versions
 *  - Document the fact this contract does not use the native solidity storage system
 *  - Switch factory to public?
 *  - Make entrypoint more flexible? v0.7.0 https://etherscan.io/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032#code
 *  - Add version to the account and the factory
 *  - Support of the EIP-1271
 *  - New nonce serie per entrypoint? In that case, first addFirstSigner
 */
contract SmartAccount is Initializable, BaseAccount {
    // ==============================
    // ========= METADATA ===========
    // ==============================

    string public constant VERSION = Metadata.VERSION;

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
    event SignerAdded(bytes1 indexed signatureType, bytes32 indexed credIdHash, uint256 pubkeyX, uint256 pubkeyY);

    // ==============================
    // ========== ERRORS ============
    // ==============================

    /// @notice This error is thrown if the factory tries to add the first signer when the nonce is not 0x00
    error InvalidSignerAddition();
    error NotTheFactory();
    error NotItself();
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

        // prevent the implementation contract from being used directly
        _disableInitializers();
    }

    /// @notice Called once during the creation of the instance. Initialize the contract with the version 1.
    function initialize() external reinitializer(1) { }

    // ==============================
    // ========= MODIFIER ===========
    // ==============================

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

    /// @notice This modifier ensure the caller is the contract itself. The only way
    ///         to call the functions flagged by this modifier is by being rooted by the
    ///         `execute` or `executeBatch` functions. Those functions can only be called
    ///         by the entrypoint contract, meaning the whole workflow defined in the EIP-4337
    ///         must be respected.
    modifier onlySelf() {
        if (msg.sender != address(this)) revert NotItself();
        _;
    }

    // ==============================
    // ======== FUNCTIONS ===========
    // ==============================

    /// @notice Allow the contract to receive native tokens
    // solhint-disable-next-line no-empty-blocks
    receive() external payable { }


    /// @notice Set a new Webauthn p256r1 new signer and emit the expected event. This function
    ///         can not override an existing signer, use `remnoveWebAuthnP256R1Signer` for this
    function _addWebAuthnSigner(uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) internal {
        // 1. Set the new signer in the vault if the signer does not already exist
        SignerVaultWebAuthnP256R1.set(credIdHash, pubkeyX, pubkeyY);

        // 2. emit the event with the added signer
        emit SignerAdded(Signature.Type.WEBAUTHN_P256R1, credIdHash, pubkeyX, pubkeyY);
    }

    /// @notice Add a Webauthn p256r1 new signer to the account
    /// @dev    This function can only be called by the account itself. The whole 4337 workflow must be respected
    /// @param  pubkeyX The X coordinate of the signer's public key.
    /// @param  pubkeyY The Y coordinate of the signer's public key.
    /// @param  credIdHash The hash of the credential ID associated to the signer
    function addWebAuthnP256R1Signer(uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) external onlySelf {
        _addWebAuthnSigner(pubkeyX, pubkeyY, credIdHash);
    }

    /// @notice Add the first signer to the account. This function is only call once by the factory
    ///         during the deployment of the account. All the future signers must be added using the
    ///         `addWebAuthnP256R1Signer` function.
    /// @dev    This function adds a signer generated using the WebAuthn protocol on the
    ///         secp256r1 curve. This function can only be called once when the nonce of the account is 0x00.
    /// @param  pubkeyX The X coordinate of the signer's public key.
    /// @param  pubkeyY The Y coordinate of the signer's public key.
    /// @param  credIdHash The hash of the credential ID associated to the signer
    function addFirstSigner(uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) external onlyFactory {
        // 1. check that the nonce is 0x00. The value of the first key is checked here
        if (getNonce() != 0) revert InvalidSignerAddition();

        // 2. add account's first signer and emit the signer addition event
        _addWebAuthnSigner(pubkeyX, pubkeyY, credIdHash);
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
        //  - 32 bytes for the usernameHash
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
        uint256 pubX = uint256(bytes32(initCode[24:56]));
        uint256 pubY = uint256(bytes32(initCode[56:88]));
        bytes32 usernameHash = bytes32(initCode[88:120]);
        bytes32 credIdHash = bytes32(initCode[120:152]);

        // 4. check the factory is the same than the one stored here
        if (userOpFactory != factory) return Signature.State.FAILURE;

        // 5. recreate the message and try to recover the signer
        bytes memory message =
            abi.encode(Signature.Type.CREATION, usernameHash, pubX, pubY, credIdHash, address(this), block.chainid);

        // 6. fetch the expected signer from the factory contract
        address expectedSigner = AccountFactory(factory).owner();

        // 7. Check the signature is valid and revert if it is not
        // NOTE: The signature prefix, added manually to identify the signature, is removed before the recovering process
        if (Signature.recover(expectedSigner, message, signature[1:]) == false) return Signature.State.FAILURE;

        // 8. Check the signer is the same than the one stored by the factory during the account creation process
        // solhint-disable-next-line var-name-mixedcase
        (bytes32 $credIdHash, uint256 $pubkeyX, uint256 $pubkeyY) = SignerVaultWebAuthnP256R1.get(credIdHash);
        if ($credIdHash != credIdHash || $pubkeyX != pubX || $pubkeyY != pubY) return Signature.State.FAILURE;

        return Signature.State.SUCCESS;
    }

    function _validateWebAuthnP256R1Signature(UserOperation calldata userOp) internal returns (uint256) {
        // 1. decode the signature
        (, bytes memory authData, bytes memory clientData, uint256 r, uint256 s, bytes32 credIdHash) =
            abi.decode(userOp.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. retrieve the public key of the signer
        (uint256 pubkeyX, uint256 pubkeyY) = SignerVaultWebAuthnP256R1.pubkey(credIdHash);
        if (pubkeyX == 0 && pubkeyY == 0) return Signature.State.FAILURE;

        // 3. reconstruct the challenge
        bytes memory packedData = abi.encode(address(this), userOp.nonce, userOp.callData, userOp.paymasterAndData);
        bytes memory encodedPackedData = abi.encode(keccak256(packedData), entryPointAddress, block.chainid);
        bytes32 challenge = keccak256(encodedPackedData);

        // 3. verify the signature
        bool isSignatureValid = IWebAuthn256r1(webAuthnVerifier).verify(
            authData, clientData, abi.encodePacked(challenge), r, s, pubkeyX, pubkeyY
        );
        if (isSignatureValid == false) return Signature.State.FAILURE;

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
        override
        returns (uint256 validationData)
    {
        bytes1 signatureType = userOp.signature[0];

        // 1.a check the signature is a "webauthn p256r1" signature
        if (signatureType == Signature.Type.WEBAUTHN_P256R1) {
            return _validateWebAuthnP256R1Signature(userOp);
        }

        // 1.b check the signature is a "creation" signature (length is checked by the signature library)
        if (signatureType == Signature.Type.CREATION) {
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
