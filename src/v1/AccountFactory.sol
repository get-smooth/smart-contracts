// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { SmartAccount } from "./Account/SmartAccount.sol";
import { Metadata } from "src/v1/Metadata.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import "src/utils/Signature.sol" as Signature;

// FIXME:   createAndInitAccount() Understand the implications of the ban system of the function

/// @title  4337-compliant Account Factory
/// @notice This contract is a 4337-compliant factory for smart-accounts. It is in charge of deploying an account
///         implementation during its construction, then deploying proxies for the users. The proxies are deployed
///         using the CREATE2 opcode and they use the implementation contract deployed on construction as a
///         reference. Once the account has been deployed by the factory, the factory is also in charge of setting
///         the first signer of the account, leading to a fully-setup account for the user.
/// @dev    The signature is only used to set the first-signer to the account. It is a EIP-191 message
///         signed by the owner. The message is the keccak256 hash of the login of the account.
///         As the address of the account is already dependant of the address of the factory, we do not need to
///         include it in the signature.
contract AccountFactory is Initializable, OwnableUpgradeable {
    // ==============================
    // ========= CONSTANT ===========
    // ==============================

    address payable public immutable accountImplementation;

    // ==============================
    // ======= EVENTS/ERRORS ========
    // ==============================

    event AccountCreated(address account, bytes authenticatorData);

    error InvalidSignature(address accountAddress, bytes authenticatorData, bytes signature);
    error InvalidAccountImplementation();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @notice Deploy the implementation of the account and store it in the storage of the factory. This
    ///         implementation will be used as the implementation reference for all the proxies deployed by this
    ///         factory.
    /// @param  _accountImplementation The address of the implementation of the smart account. Must never be changed!!
    /// @dev    All the arguments passed to the constructor function are used to set immutable variables.
    constructor(address _accountImplementation) {
        // 1. set the address of the implementation account -- THIS ADDRESS MUST NEVER BE CHANGED (!!)
        if (_accountImplementation == address(0)) revert InvalidAccountImplementation();
        accountImplementation = payable(_accountImplementation);

        // 2. prevent the implementation contract from being used directly
        _disableInitializers();
    }

    // The initialize function will be used to set up the initial state of the contract.
    function initialize(address owner) public virtual reinitializer(1) {
        // 1. set the owner
        __Ownable_init(owner);
    }

    // ==============================
    // ======== FUNCTIONS ===========
    // ==============================

    /// @notice This function checks if the signature is signed by the operator (owner)
    /// @param  accountAddress The address of the account that would be deployed
    /// @param  authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    /// @param  signature Signature made off-chain by made the operator of the factory (owner). It gates the use of the
    ///         factory.
    /// @return True if the signature is legit, false otherwise
    /// @dev    Incorrect signatures are expected to lead to a revert by the library used
    function _isSignatureLegit(
        address accountAddress,
        bytes calldata authenticatorData,
        bytes calldata signature
    )
        internal
        view
        virtual
        returns (bool)
    {
        // 1. Recreate the message signed by the operator (owner)
        bytes memory message = abi.encode(Signature.Type.CREATION, authenticatorData, accountAddress, block.chainid);

        // 2. Try to recover the address and return if the signature is legit
        return Signature.recover(owner(), message, signature[1:]);
    }

    /// @notice This function either deploys an account and sets its first signer or returns the address of an existing
    ///         account based on the parameter given
    /// @param  authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    /// @param  signature Signature made off-chain by made the operator of the factory (owner). It gates the use of the
    ///         factory.
    /// @return The address of the existing account (either deployed by this function or not)
    function createAndInitAccount(
        bytes calldata authenticatorData,
        bytes calldata signature
    )
        external
        virtual
        returns (address)
    {
        // 1. extract the signer from the authenticatorData
        (, bytes32 credIdHash, uint256 pubX, uint256 pubY) =
            SignerVaultWebAuthnP256R1.extractSignerFromAuthData(authenticatorData);

        // 2. get the address of the account if it exists
        address accountAddress = getAddress(credIdHash, pubX, pubY);

        // 3. check if the account is already deployed and return prematurely if it is
        if (accountAddress.code.length > 0) return accountAddress;

        // 4. check if the signature is valid
        if (_isSignatureLegit(accountAddress, authenticatorData, signature) == false) {
            revert InvalidSignature(accountAddress, authenticatorData, signature);
        }

        // 5. deploy the proxy for the user. During the deployment, the initialize function in the implementation
        // is called using the `delegatecall` opcode
        SmartAccount account = SmartAccount(
            payable(
                new ERC1967Proxy{ salt: calculateSalt(credIdHash, pubX, pubY) }(
                    accountImplementation, abi.encodeWithSelector(SmartAccount.initialize.selector)
                )
            )
        );

        // 6. set the initial signer of the account defined in the authenticatorData
        account.addFirstSigner(authenticatorData);

        // 7. emit the event and return the address of the deployed account
        emit AccountCreated(address(account), authenticatorData);
        return address(account);
    }

    /// @notice This function calculates the salt used to deploy the account
    /// @dev This function must never be changed (!!)
    /// @param credIdHash The hash of the credential ID of the signer
    /// @param pubkeyX The x-coordinate of the public key of the signer
    /// @param pubkeyY The y-coordinate of the public key of the signer
    function calculateSalt(bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) internal pure returns (bytes32) {
        // 1. encode the signer and hash the result to get the salt
        return keccak256(abi.encodePacked(credIdHash, pubkeyX, pubkeyY));
    }

    /// @notice This utility function returns the address of the account that would be deployed using the salt
    /// @dev    This is the under the hood formula used by the CREATE2 opcode. This function must never be changed (!!)
    /// @param  credIdHash The hash of the credential ID of the signer
    /// @param  pubkeyX The x-coordinate of the public key of the signer
    /// @param  pubkeyY The y-coordinate of the public key of the signer
    /// @return The address of the account that would be deployed
    function getAddress(bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), // init code hash prefix
                            address(this), // deployer address
                            calculateSalt(credIdHash, pubkeyX, pubkeyY),
                            keccak256( // the init code hash
                                abi.encodePacked(
                                    // creation code of the contract deployed
                                    type(ERC1967Proxy).creationCode,
                                    // arguments passed to the constructor of the contract deployed
                                    abi.encode(
                                        accountImplementation, abi.encodeWithSelector(SmartAccount.initialize.selector)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    /// @notice This utility function returns the address of the account that would be deployed using the authData
    /// @dev    The salt is calculated using the signer extracted from the authenticatorData.  This function must never
    ///         be changed (!!)
    /// @param  authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    /// @return The address of the account that would be deployed
    function getAddress(bytes calldata authenticatorData) external view returns (address) {
        // 1. extract the signer from the authenticatorData
        (, bytes32 credIdHash, uint256 pubX, uint256 pubY) =
            SignerVaultWebAuthnP256R1.extractSignerFromAuthData(authenticatorData);

        // 2. return the address of the account that would be deployed
        return getAddress(credIdHash, pubX, pubY);
    }

    function version() external pure virtual returns (uint256) {
        return Metadata.VERSION;
    }
}

// NOTE:
// - The creation method defined in this contract follow the EIP-4337 recommandations.
//   That's why the methods return the address of the already deployed account if it exists.
//   https://eips.ethereum.org/EIPS/eip-4337#first-time-account-creation
//
// - CREATE2 is used to deploy the proxy for our users. The formula of this deterministic computation
//   depends on these parameters:
//   - the address of the factory
//   - the salt (`keccak256(abi.encodePacked(credIdHash, pubX, pubY))`)
//   - the implementation of the ERC1967Proxy (included in the init code hash)
//   - the arguments passed to the constructor of the ERC1967Proxy (included in the init code hash):
//      - the address of the implementation of the account
//      - the signature selector of the initialize function present in the account implementation (first 4-bytes)
//      - the salt (`keccak256(abi.encodePacked(credIdHash, pubX, pubY))`)
//
// - Once set, it's not possible to change the account implementation later.
// - Once deployed by the constructor, it's not possible to change the instance of the account implementation.
// - The implementation of the proxy is hardcoded, it is not possible to change it later.
