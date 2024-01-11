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
/// @dev    The name service signature is only used to set the first-signer to the account. It is a EIP-191 message
///         signed by the nameServiceOwner. The message is the keccak256 hash of the login of the account.
contract AccountFactory {
    address public immutable accountImplementation;
    address public immutable nameServiceOwner;

    event AccountCreatedAndInit(bytes32 loginHash, address account, bytes credId, uint256 pubKeyX, uint256 pubKeyY);

    error InvalidNameServiceSignature(bytes32 loginHash, bytes nameServiceSignature);

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

    /// @notice This function check if an account already exists based on the loginHash given
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @return The address of the account if it exists, address(0) otherwise
    function _checkAccountExistence(bytes32 loginHash) internal view returns (address) {
        // calculate the address of the account based on the loginHash and return it if it exists
        address calulatedAddress = getAddress(loginHash);
        return calulatedAddress.code.length > 0 ? calulatedAddress : address(0);
    }

    /// @notice This function check if the signature of the name service is signed by the correct entity
    /// @param  message The message that has been signed
    /// @param  signature The signature of the message
    /// @return True if the signature is legit, false otherwise
    /// @dev    Incorrect signatures are expected to lead to a revert by the library used
    function _isNameServiceSignatureLegit(bytes32 message, bytes calldata signature) internal view returns (bool) {
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);
        address recoveredAddress = ECDSA.recover(hash, signature);
        return recoveredAddress == nameServiceOwner;
    }

    /// @notice This is the one-step scenario. This function either deploys an account and sets its first signer
    ///         or returns the address of an existing account based on the parameter given
    /// @param  pubKeyX The X coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  pubKeyY The Y coordinate of the public key of the first signer. We use the r1 curve here
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @param  credId The WebAuthn credential ID of the first signer. Take a look to the WebAuthn specification
    /// @param  nameServiceSignature The signature of the name service. Its recovery must match the nameServiceOwner.
    ///         The loginHash is expected to be the hash used by the recover function.
    /// @return The address of the account (either deployed or not)
    function createAndInitAccount(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes calldata credId,
        bytes calldata nameServiceSignature
    )
        external
        returns (address)
    {
        // check if the account is already deployed and return prematurely if it is
        address alreadyDeployedAddress = _checkAccountExistence(loginHash);
        if (alreadyDeployedAddress != address(0)) {
            return alreadyDeployedAddress;
        }

        // check if the signature of the name service is valid
        if (_isNameServiceSignatureLegit(loginHash, nameServiceSignature) == false) {
            revert InvalidNameServiceSignature(loginHash, nameServiceSignature);
        }

        // deploy the proxy for the user. During the deployment, the
        // initialize function in the implementation contract is called
        // using the `delegatecall` opcode
        Account account = Account(
            payable(
                new ERC1967Proxy{ salt: loginHash }(
                    address(accountImplementation), abi.encodeCall(Account.initialize, (loginHash))
                )
            )
        );

        // set the first signer of the account using the parameters given
        account.addFirstSigner(pubKeyX, pubKeyY, credId);

        emit AccountCreatedAndInit(loginHash, address(account), credId, pubKeyX, pubKeyY);

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
                                        address(accountImplementation), abi.encodeCall(Account.initialize, (loginHash))
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
//   - the loginHash (used as the salt)
//   - the implementation of the ERC1967Proxy (included in the init code hash)
//   - the arguments passed to the constructor of the ERC1967Proxy (included in the init code hash):
//      - the address of the implementation of the account
//      - the signature selector of the initialize function present in the account implementation (first 4-bytes)
//      - the value of loginHash
//
// - Once set, it's not possible to change the account implementation later.
// - Once deployed by the constructor, it's not possible to change the instance of the account implementation.
// - The implementation of the proxy is hardcoded, it is not possible to change it later.
