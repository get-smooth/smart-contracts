// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { Account } from "./Account.sol";

contract AccountFactory {
    address public immutable accountImplementation;
    address public immutable nameServiceOwner;

    event AccountCreated(bytes32 loginHash, address account);

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

    /// @notice This is the multi-steps scenario. This function either deploys an account or returns the address of
    ///         an existing account based on the parameter given. In any case this function set the first signer.
    /// @param  loginHash The keccak256 hash of the login of the account
    /// @return The address of the account (either deployed or not)
    function createAccount(bytes32 loginHash) external returns (address) {
        // check if the account is already deployed and return prematurely if it is
        address alreadyDeployedAddress = _checkAccountExistence(loginHash);
        if (alreadyDeployedAddress != address(0)) {
            return alreadyDeployedAddress;
        }

        // deploy the proxy for the user. During the deployment call, the
        // initialize function in the implementation contract is called
        // using the `delegatecall` opcode
        Account account = Account(
            payable(
                new ERC1967Proxy{ salt: loginHash }(
                    address(accountImplementation), abi.encodeCall(Account.initialize, (loginHash))
                )
            )
        );

        emit AccountCreated(loginHash, address(account));

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
