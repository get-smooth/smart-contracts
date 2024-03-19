// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import "src/utils/Signature.sol" as Signature;
import { SmartAccount } from "./Account/SmartAccount.sol";
import { Metadata } from "src/v1/Metadata.sol";

// FIXME:   createAndInitAccount() Understand the implications of the ban system of the function
// TODO:    What about storing the credId off-chain for the login scenario ? As we moved from `credId` to `credIdHash`
//          for the create function, we do not log the credId anymore. Investigate

/// @title  4337-compliant Account Factory
/// @notice This contract is a 4337-compliant factory for smart-accounts. It is in charge of deploying an account
///         implementation during its construction, then deploying proxies for the users. The proxies are deployed
///         using the CREATE2 opcode and they use the implementation contract deployed on construction as a
///         reference. Once the account has been deployed by the factory, the factory is also in charge of setting
///         the first signer of the account, leading to a fully-setup account for the user.
/// @dev    The signature is only used to set the first-signer to the account. It is a EIP-191 message
///         signed by the owner. The message is the keccak256 hash of the login of the account.
contract AccountFactory is Ownable {
    // ==============================
    // ========= METADATA ===========
    // ==============================

    string public constant VERSION = Metadata.VERSION;

    // ==============================
    // ========= CONSTANT ===========
    // ==============================

    address payable public immutable accountImplementation;

    event AccountCreated(
        bytes32 usernameHash, address account, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    error InvalidSignature(bytes32 usernameHash, bytes signature);

    /// @notice Deploy the implementation of the account and store it in the storage of the factory. This
    ///         implementation will be used as the implementation reference for all the proxies deployed by this
    ///         factory. To make sure the instance deployed cannot be used, we brick it by calling the `initialize`
    ///         function and setting an invalid first signer.
    /// @param  entryPoint The unique address of the entrypoint (EIP-4337 related)
    /// @param  webAuthnVerifier The address of the crypto library that will be used by
    ///         the account to verify the WebAuthn signature of the signer(s)
    /// @param  owner The address used to verify the signature. It is the owner of the factory.
    /// @dev    The account deployed here is expected to be proxied later, its own storage won't be used.
    ///         All the arguments passed to the constructor function are used to set immutable variables.
    ///         The account deployed is expected to be bricked by the `initialize` function.
    constructor(address entryPoint, address webAuthnVerifier, address owner) Ownable(owner) {
        // deploy the implementation of the account
        SmartAccount account = new SmartAccount(entryPoint, webAuthnVerifier);

        // set the address of the implementation deployed
        accountImplementation = payable(address(account));
    }

    /// @notice This function check if the signature is signed by the correct entity
    /// @param  pubKeyX The X coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  pubKeyY The Y coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  usernameHash The keccak256 hash of the login of the account
    /// @param  credIdHash The hash of the WebAuthn credential ID of the signer. Check the specification
    /// @param  signature Signature made off-chain. Its recovery must match the owner.
    /// @return True if the signature is legit, false otherwise
    /// @dev    Incorrect signatures are expected to lead to a revert by the library used
    function _isSignatureLegit(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 usernameHash,
        bytes32 credIdHash,
        address accountAddress,
        bytes calldata signature
    )
        internal
        returns (bool)
    {
        // recreate the message signed by the owner
        bytes memory message = abi.encode(
            Signature.Type.CREATION, usernameHash, pubKeyX, pubKeyY, credIdHash, accountAddress, block.chainid
        );

        // try to recover the address and return the result
        return Signature.recover(owner(), message, signature);
    }

    /// @notice This is the one-step scenario. This function either deploys an account and sets its first signer
    ///         or returns the address of an existing account based on the parameter given
    /// @param  pubKeyX The X coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  pubKeyY The Y coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  usernameHash The keccak256 hash of the login of the account
    /// @param  credIdHash The hash of the WebAuthn credential ID of the signer. Check the specification
    /// @param  signature Signature made off-chain. Its recovery must match the owner.
    ///         The usernameHash is expected to be the hash used by the recover function.
    /// @return The address of the account (either deployed or not)
    function createAndInitAccount(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 usernameHash,
        bytes32 credIdHash,
        bytes calldata signature
    )
        external
        returns (address)
    {
        // 1. get the address of the account if it exists
        address accountAddress = getAddress(usernameHash);

        // 2. check if the account is already deployed and return prematurely if it is
        if (accountAddress.code.length > 0) return accountAddress;

        // 3. check if the signature is valid
        if (_isSignatureLegit(pubKeyX, pubKeyY, usernameHash, credIdHash, accountAddress, signature) == false) {
            revert InvalidSignature(usernameHash, signature);
        }

        // 4. deploy the proxy for the user. During the deployment, the initialize function in the implementation
        // is called using the `delegatecall` opcode
        SmartAccount account = SmartAccount(
            payable(
                new ERC1967Proxy{ salt: usernameHash }(
                    accountImplementation, abi.encodeWithSelector(SmartAccount.initialize.selector)
                )
            )
        );

        // 5. set the initial signer of the account using the parameters given
        account.addFirstSigner(pubKeyX, pubKeyY, credIdHash);

        // 6. emit the event and return the address of the deployed account
        emit AccountCreated(usernameHash, address(account), credIdHash, pubKeyX, pubKeyY);
        return address(account);
    }

    /// @notice This utility function returns the address of the account that would be deployed
    /// @dev    This is the under the hood formula used by the CREATE2 opcode
    /// @param  usernameHash The keccak256 hash of the login of the account
    /// @return The address of the account that would be deployed
    function getAddress(bytes32 usernameHash) public view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), // init code hash prefix
                            address(this), // deployer address
                            usernameHash, // the salt used to deploy the contract
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
}

// NOTE:
// - The creation method defined in this contract follow the EIP-4337 recommandations.
//   That's why the methods return the address of the already deployed account if it exists.
//   https://eips.ethereum.org/EIPS/eip-4337#first-time-account-creation
//
// - CREATE2 is used to deploy the proxy for our users. The formula of this deterministic computation
//   depends on these parameters:
//   - the address of the factory
//   - the usernameHash
//   - the implementation of the ERC1967Proxy (included in the init code hash)
//   - the arguments passed to the constructor of the ERC1967Proxy (included in the init code hash):
//      - the address of the implementation of the account
//      - the signature selector of the initialize function present in the account implementation (first 4-bytes)
//      - the usernameHash
//
// - Once set, it's not possible to change the account implementation later.
// - Once deployed by the constructor, it's not possible to change the instance of the account implementation.
// - The implementation of the proxy is hardcoded, it is not possible to change it later.
