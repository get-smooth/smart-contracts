// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { AccountFactory } from "src/AccountFactory.sol";
import "src/utils/Signature.sol" as Signature;

struct ValidCreationParams {
    uint256 pubKeyX;
    uint256 pubKeyY;
    bytes32 usernameHash;
    bytes32 credIdHash;
    address signer;
    bytes signature;
}

contract BaseTest is Test {
    VmSafe.Wallet internal signer;

    // store a set of valid creation parameters that can be used in tests
    ValidCreationParams internal validCreate;

    // use a random username hash
    bytes32 internal __usernameHash = 0x975f1d0637811aba12c41f7b0d68ee42aa76a3a1cba43b96f60f0e3ea2f2206a;

    // generate a credId hash that corresponds to the login
    bytes32 internal __credIdHash = 0x511deddb8b836e8ced2f5e8a4ee0ac63ae4095b426398cc712aa772a4c68a099;

    // generate a set of valid creation parameters
    constructor() {
        // generate the wallet for the secret signer
        signer = vm.createWallet(4337);

        // TODO: remove valid create here

        // recreate the message to sign
        bytes memory message = abi.encode(
            Signature.Type.CREATION,
            __usernameHash,
            signer.publicKeyX,
            signer.publicKeyY,
            __credIdHash,
            address(32),
            block.chainid
        );

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and get the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // save the valid creation parameters
        validCreate = ValidCreationParams({
            pubKeyX: signer.publicKeyX,
            pubKeyY: signer.publicKeyY,
            usernameHash: __usernameHash,
            credIdHash: __credIdHash,
            signer: signer.addr,
            signature: signature
        });
    }

    uint256 internal constant P256R1_MAX =
        115_792_089_210_356_248_762_697_446_949_407_573_530_086_143_415_290_314_195_533_631_308_867_097_853_951;

    modifier assumeNoPrecompile(address fuzzedAddress) {
        assumeNotPrecompile(fuzzedAddress);

        _;
    }

    function _craftCreationSignature(address factoryAddress) internal returns (bytes memory signature) {
        address accountAddress = AccountFactory(factoryAddress).getAddress(validCreate.usernameHash);

        // recreate the message to sign
        bytes memory message = abi.encode(
            Signature.Type.CREATION,
            __usernameHash,
            signer.publicKeyX,
            signer.publicKeyY,
            __credIdHash,
            accountAddress,
            block.chainid
        );

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and get the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, hash);
        signature = abi.encodePacked(r, s, v);
    }

    function boundP256R1(uint256 x) internal pure returns (uint256) {
        return x % P256R1_MAX;
    }

    function truncBytes(
        bytes calldata data,
        uint256 start,
        uint256 end
    )
        external
        pure
        returns (bytes memory truncData)
    {
        truncData = data[start:end];
    }

    function _truncBytes(bytes memory data, uint256 start, uint256 end) internal view returns (bytes memory truncData) {
        truncData = BaseTest(address(this)).truncBytes(data, start, end);
    }
}
