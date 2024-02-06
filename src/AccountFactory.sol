// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { Account } from "./Account.sol";

// TODO: Implement an universal registry and use it to store the value of `nameServiceOwner`

/// @title  4337-compliant Account Factory
/// @notice This contract is a 4337-compliant factory for smart-accounts. It is in charge of deploying an account
///         implementation during its construction, then deploying proxies for the users. The proxies are deployed
///         using the CREATE2 opcode and they use the implementation contract deployed on construction as a
///         reference. Once the account has been deployed by the factory, the factory is also in charge of setting
///         the first signer of the account, leading to a fully-setup account for the user.
/// @dev    The signature is only used to set the first-signer to the account. It is a EIP-191 message
///         signed by the admin. The message is the keccak256 hash of the login of the account.
contract AccountFactory {
    address payable public immutable accountImplementation;
    address public immutable admin;

    event AccountCreated(
        bytes32 loginHash, address account, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    error InvalidSignature(bytes32 loginHash, bytes signature);

    /// @notice Deploy the implementation of the account and store it in the storage of the factory. This
    ///         implementation will be used as the implementation reference for all the proxies deployed by this
    ///         factory. To make sure the instance deployed cannot be used, we brick it by calling the `initialize`
    ///         function and setting an invalid first signer.
    /// @param  entryPoint The unique address of the entrypoint (EIP-4337 related)
    /// @param  webAuthnVerifier The address of the crypto library that will be used by
    ///         the account to verify the WebAuthn signature of the signer(s)
    /// @param  _admin The address used to verify the signature
    ///         This address is stored in the storage of this contract that validate future signatures
    /// @dev    The account deployed here is expected to be proxied later, its own storage won't be used.
    ///         All the arguments passed to the constructor function are used to set immutable variables.
    ///         As a valid signature from the admin is required to set the first signer of the account,
    ///         there is no need to make the account inoperable. No one will be able to use it.
    constructor(address entryPoint, address webAuthnVerifier, address _admin) {
        // deploy the implementation of the account
        Account account = new Account(entryPoint, webAuthnVerifier);

        // Brick the instance deployed by initiliaze the account and set an invalid first signer
        account.initialize();
        account.addFirstSigner(0, 0, bytes32(0));

        // set the address of the implementation deployed
        accountImplementation = payable(address(account));
        // set the address of the expected signer of the signature
        admin = _admin;
    }

    /// @notice This function check if an account already exists based on the loginHash given
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @return The address of the account if it exists, address(0) otherwise
    function _checkAccountExistence(bytes32 loginHash) internal view returns (address) {
        // calculate the address of the account based on the loginHash and return it if it exists
        address calulatedAddress = getAddress(loginHash);
        return calulatedAddress.code.length > 0 ? calulatedAddress : address(0);
    }

    /// @notice This function check if the signature is signed by the correct entity
    /// @param  pubKeyX The X coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  pubKeyY The Y coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @param  credId The WebAuthn credential ID of the first signer. Take a look to the WebAuthn specification
    /// @param  signature Signature made off-chain. Its recovery must match the admin.
    /// @return True if the signature is legit, false otherwise
    /// @dev    Incorrect signatures are expected to lead to a revert by the library used
    function _isSignatureLegit(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes calldata credId,
        bytes calldata signature
    )
        internal
        view
        returns (bool)
    {
        // FIXME: First param is signature type -- MOVE IT TO A ENUM ?
        bytes memory message = abi.encode(0x00, loginHash, pubKeyX, pubKeyY, credId);
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);
        address recoveredAddress = ECDSA.recover(hash, signature);
        return recoveredAddress == admin;
    }

    /// @notice This is the one-step scenario. This function either deploys an account and sets its first signer
    ///         or returns the address of an existing account based on the parameter given
    /// @param  pubKeyX The X coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  pubKeyY The Y coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @param  credId The WebAuthn credential ID of the first signer. Take a look to the WebAuthn specification
    /// @param  signature Signature made off-chain. Its recovery must match the admin.
    ///         The loginHash is expected to be the hash used by the recover function.
    /// @return The address of the account (either deployed or not)
    function createAndInitAccount(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes calldata credId,
        bytes calldata signature
    )
        external
        returns (address)
    {
        // check if the account is already deployed and return prematurely if it is
        address alreadyDeployedAddress = _checkAccountExistence(loginHash);
        if (alreadyDeployedAddress != address(0)) {
            return alreadyDeployedAddress;
        }

        // check if the signature is valid
        if (_isSignatureLegit(pubKeyX, pubKeyY, loginHash, credId, signature) == false) {
            revert InvalidSignature(loginHash, signature);
        }

        // deploy the proxy for the user. During the deployment, the initialize function in the implementation contract
        // is called using the `delegatecall` opcode
        Account account = Account(
            payable(
                new ERC1967Proxy{ salt: loginHash }(
                    accountImplementation, abi.encodeWithSelector(Account.initialize.selector)
                )
            )
        );

        // hash the credId to prepare it for the storage in the account
        bytes32 credIdHash = keccak256(credId);

        // set the first signer of the account using the parameters given
        account.addFirstSigner(pubKeyX, pubKeyY, credIdHash);

        emit AccountCreated(loginHash, address(account), credIdHash, pubKeyX, pubKeyY);

        return address(account);
    }

    /// @notice This utility function returns the address of the account that would be deployed
    /// @dev    This is the under the hood formula used by the CREATE2 opcode
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @return The address of the account that would be deployed
    function getAddress(bytes32 loginHash) public view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), // init code hash prefix
                            address(this), // deployer address
                            loginHash, // the salt used to deploy the contract
                            keccak256( // the init code hash
                                abi.encodePacked(
                                    // creation code of the contract deployed
                                    type(ERC1967Proxy).creationCode,
                                    // arguments passed to the constructor of the contract deployed
                                    abi.encode(
                                        accountImplementation, abi.encodeWithSelector(Account.initialize.selector)
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
//   - the loginHash
//   - the implementation of the ERC1967Proxy (included in the init code hash)
//   - the arguments passed to the constructor of the ERC1967Proxy (included in the init code hash):
//      - the address of the implementation of the account
//      - the signature selector of the initialize function present in the account implementation (first 4-bytes)
//      - the loginHash
//
// - Once set, it's not possible to change the account implementation later.
// - Once deployed by the constructor, it's not possible to change the instance of the account implementation.
// - The implementation of the proxy is hardcoded, it is not possible to change it later.
