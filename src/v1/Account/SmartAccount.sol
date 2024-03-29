// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { UserOperation } from "@eth-infinitism/interfaces/UserOperation.sol";
import { BaseAccount } from "@eth-infinitism/core/BaseAccount.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IWebAuthn256r1 } from "@webauthn/IWebAuthn256r1.sol";
import { UV_FLAG_MASK } from "@webauthn/utils.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import "src/utils/Signature.sol" as Signature;
import { Metadata } from "src/v1/Metadata.sol";
import { SmartAccountTokensSupport } from "src/v1/Account/SmartAccountTokensSupport.sol";
import { SmartAccountEIP1271 } from "src/v1/Account/SmartAccountEIP1271.sol";

/**
 * TODO:
 *  - Take a look to proxy's versions
 *  - New nonce serie per entrypoint? In that case, first addFirstSigner
 */
contract SmartAccount is Initializable, BaseAccount, SmartAccountTokensSupport, SmartAccountEIP1271 {
    // ==============================
    // ========= METADATA ===========
    // ==============================

    uint256 public constant VERSION = Metadata.VERSION;

    // ==============================
    // ========= CONSTANTS ==========
    // ==============================

    address public immutable webAuthnVerifierAddress;
    address internal immutable entryPointAddress;

    // ==============================
    // =========== STATE ============
    // ==============================

    address internal factoryAddress;

    // ==============================
    // ======= EVENTS/ERRORS ========
    // ==============================

    /// @notice Emitted every time a signer is added to the account
    /// @dev The credIdHash is indexed to allow off-chain services to track account with same signer authorized
    ///      The credId is emitted for off-chain UX purpose
    event SignerAdded(
        bytes1 indexed signatureType, bytes credId, bytes32 indexed credIdHash, uint256 pubkeyX, uint256 pubkeyY
    );

    /// @notice Log the removal of a signer from the account with the previous public key
    /// @dev The credIdHash is indexed to allow off-chain services to track account with same signer authorized
    event SignerRemoved(
        bytes1 indexed signatureType, bytes32 indexed credIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY
    );

    /// @notice This error is thrown if the factory tries to add the first signer when the nonce is not 0x00
    error InvalidFirstSignerAddition();
    error InvalidSignerAddition();
    error NotTheFactory();
    error NotItself();
    /// @notice This error is thrown if arguments passed to the `executeBatch` function are not of the same length
    /// @dev    `values` can be of length 0 if no value is passed to the calls
    error IncorrectExecutionBatchParameters();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @dev   Do not store any state in this function as the contract will be proxified, only immutable variables
    /// @param _entryPoint The address of the 4337 entrypoint used by this implementation
    /// @param _webAuthnVerifier The address of the webauthn library used for verify the webauthn signature
    constructor(address _entryPoint, address _webAuthnVerifier) {
        entryPointAddress = _entryPoint;
        webAuthnVerifierAddress = _webAuthnVerifier;

        // prevent the implementation contract from being used directly
        _disableInitializers();
    }

    /// @notice Called once during the creation of the instance. Initialize the contract with the version 1.
    // solhint-disable-next-line no-empty-blocks
    function initialize() external reinitializer(1) {
        // Address of the factory that initialize the proxy that points to this implementation
        // Only the factory will have the ability to set the first signer when nonce==0
        factoryAddress = msg.sender;
    }

    // ==============================
    // ========= MODIFIER ===========
    // ==============================

    /// @notice This modifier ensure the caller is the factory that deployed this contract
    modifier onlyFactory() {
        if (msg.sender != factoryAddress) revert NotTheFactory();
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

    /// @notice Return the entrypoint used by this implementation
    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(entryPointAddress);
    }

    /// @notice Return the factory that initialized this contract
    /// @return The address of the factory
    function factory() external view returns (address) {
        return factoryAddress;
    }

    /// @notice Return the webauthn verifier used by this contract
    /// @return The address of the webauthn verifier
    function webAuthnVerifier() external view returns (address) {
        return webAuthnVerifierAddress;
    }

    /// @notice Used internally to get the webauthn verifier
    /// @return The 256r1 webauthn verifier
    function webauthn256R1Verifier() internal view override returns (IWebAuthn256r1) {
        return IWebAuthn256r1(webAuthnVerifierAddress);
    }

    /// @notice Remove an existing Webauthn p256r1.
    /// @dev    This function can only be called by the account itself. The whole 4337 workflow must be respected
    /// @param  credIdHash The hash of the credential ID associated to the signer
    function removeWebAuthnP256R1Signer(bytes32 credIdHash) external onlySelf {
        // 1. get the current public key stored
        (uint256 pubkeyX, uint256 pubkeyY) = SignerVaultWebAuthnP256R1.pubkey(credIdHash);

        // 2. remove the signer from the vault
        SignerVaultWebAuthnP256R1.remove(credIdHash);

        // 3. emit the event with the removed signer
        emit SignerRemoved(Signature.Type.WEBAUTHN_P256R1, credIdHash, pubkeyX, pubkeyY);
    }

    /// @notice Extract the signer from the authenticatorData
    /// @dev    This function is free to be called (!!)
    /// @param authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    /// @return credId The credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function extractSignerFromAuthData(bytes calldata authenticatorData)
        public
        pure
        returns (bytes memory credId, bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (credId, credIdHash, pubkeyX, pubkeyY) = SignerVaultWebAuthnP256R1.extractSignerFromAuthData(authenticatorData);
    }

    /// @notice Set a new Webauthn p256r1 new signer and emit the expected event. This function
    ///         can not override an existing signer, use `remnoveWebAuthnP256R1Signer` for this
    /// @param authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    function _addWebAuthnSigner(bytes calldata authenticatorData)
        internal
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        // 0. verify the UV is set in the authenticatorData
        if ((authenticatorData[32] & UV_FLAG_MASK) == 0) revert InvalidSignerAddition();

        // 1. extract the signer from the authenticatorData
        // @DEV: WHY CANNOT WE USE `bytes memory` in the tuple without specify other fucking types?
        bytes memory credId;
        (credId, credIdHash, pubkeyX, pubkeyY) = extractSignerFromAuthData(authenticatorData);

        // 2. Set the new signer in the vault if the signer does not already exist
        SignerVaultWebAuthnP256R1.set(credIdHash, pubkeyX, pubkeyY);

        // 3. emit the event with the added signer
        emit SignerAdded(Signature.Type.WEBAUTHN_P256R1, credId, credIdHash, pubkeyX, pubkeyY);
    }

    /// @notice Add a Webauthn p256r1 new signer to the account
    /// @dev   This function can only be called by the account itself. The whole 4337 workflow must be respected
    /// @param authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    function addWebAuthnP256R1Signer(bytes calldata authenticatorData)
        external
        onlySelf
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        return _addWebAuthnSigner(authenticatorData);
    }

    /// @notice Add the first signer to the account. This function is only call once by the factory
    ///         during the deployment of the account. All the future signers must be added using the
    ///         `addWebAuthnP256R1Signer` function.
    /// @dev    This function adds a signer generated using the WebAuthn protocol on the
    ///         secp256r1 curve. This function can only be called once when the nonce of the account is 0x00.
    /// @param authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    function addFirstSigner(bytes calldata authenticatorData) external onlyFactory {
        // 1. check that the nonce is 0x00. The value of the first key is checked here
        if (getNonce() != 0) revert InvalidFirstSignerAddition();

        // 2. add account's first signer and emit the signer addition event
        _addWebAuthnSigner(authenticatorData);
    }

    /// @notice Return a signer stored in the account using its credIdHash. When storing a signer, the credId
    ///         is hashed using keccak256 because its length is unpredictable.
    /// @dev    This function is free to be called (!!)
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

    /// @notice The validation of the creation signature
    /// @dev This creation signature is the signature that can only be used once during account creation (nonce == 0).
    ///      This signature is different from the ones the account will use for validation for the rest of its lifetime.
    ///      This signature is not a webauthn signature made on p256r1 but a traditional EIP-191 signature made on
    ///      p256k1 and signed by the operator (owner) of the factory to prove the account has been authorized for
    ///     deployment. The use of the account factory is gated by this signature.
    /// @param signature The signature field presents in the userOp.
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

        // 2. get the address of the factory and check it is the expected one
        address accountFactory = address(bytes20(initCode[:20]));
        if (accountFactory != factoryAddress) return Signature.State.FAILURE;

        // 3. decode the rest of the initCode (skip the first 4 bytes -- function selector)
        (bytes memory authenticatorData,) = abi.decode(initCode[24:], (bytes, bytes));

        // 4. extract the signer from the authenticatorData
        // TODO: once tested, rework this shit by using a more efficient way
        (, bytes32 credIdHash, uint256 pubX, uint256 pubY) =
            SmartAccount(payable(address(this))).extractSignerFromAuthData(authenticatorData);

        // 5. recreate the message and try to recover the signer
        bytes memory message = abi.encode(Signature.Type.CREATION, authenticatorData, address(this), block.chainid);

        // 6. fetch the expected signer from the factory contract
        address expectedSigner = AccountFactory(factoryAddress).owner();

        // 7. Check the signature is valid and revert if it is not
        // NOTE: The signature prefix, added manually to identify the signature, is removed before the recovery process
        if (Signature.recover(expectedSigner, message, signature[1:]) == false) return Signature.State.FAILURE;

        // 8. Ensure the signer is allowed. This is the signer added by the factory during the deployment process.
        // solhint-disable-next-line var-name-mixedcase
        (bytes32 storedCredIdHash, uint256 storedPubX, uint256 storedPubY) = SignerVaultWebAuthnP256R1.get(credIdHash);
        if (storedCredIdHash != credIdHash || storedPubX != pubX || storedPubY != pubY) return Signature.State.FAILURE;

        return Signature.State.SUCCESS;
    }

    /// @notice Validate a WebAuthn p256r1 signature
    /// @dev    Except for the deployment signature (nonce == 0), all the intent of the user to interact with the
    //          account must be signed using the WebAuthn protocol on the secp256r1 curve. This function validates
    //          the signature. The expected challenge is constructed on-chain using the data from the userOp and
    //          the environment (entrypoint address, chainid, this contract address)...
    /// @param userOp The user operation to validate
    function _validateWebAuthnP256R1Signature(UserOperation calldata userOp) internal returns (uint256) {
        // 1. decode the signature
        ( /*identifier*/ , bytes memory authData, bytes memory clientData, uint256 r, uint256 s, bytes32 credIdHash) =
            abi.decode(userOp.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. retrieve the public key of the signer
        (uint256 pubkeyX, uint256 pubkeyY) = SignerVaultWebAuthnP256R1.pubkey(credIdHash);
        if (pubkeyX == 0 && pubkeyY == 0) return Signature.State.FAILURE;

        // 3. reconstruct the challenge signed by the user. This challenge is passed to the authenticator
        bytes memory packedData = abi.encode(address(this), userOp.nonce, userOp.callData, userOp.paymasterAndData);
        bytes memory encodedPackedData = abi.encode(keccak256(packedData), entryPointAddress, block.chainid);
        bytes32 challenge = keccak256(encodedPackedData);

        // 3. verify the signature
        bool isSignatureValid = IWebAuthn256r1(webAuthnVerifierAddress).verify(
            authData, clientData, abi.encodePacked(challenge), r, s, pubkeyX, pubkeyY
        );
        if (isSignatureValid == false) return Signature.State.FAILURE;

        return Signature.State.SUCCESS;
    }

    /// @notice Validate the signature field presents in the userOp
    /// @dev We do not return any time-range data, only the signature validation
    /// @param userOp The user operation to validate
    /// @param * The hash of the userOp
    /// @return validationData signature and time-range of this operation.
    ///         - 20 bytes: sigAuthorizer - 0 for valid signature, 1 to mark signature failure
    ///         - 06 bytes: validUntil - last timestamp this operation is valid. 0 for "indefinite" (UNUSED)
    ///         - 06 bytes: validAfter - first timestamp this operation is valid (UNUSED)
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
