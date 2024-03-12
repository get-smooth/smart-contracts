// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";

struct ValidCreationParams {
    uint256 pubKeyX;
    uint256 pubKeyY;
    string login;
    bytes32 loginHash;
    bytes32 credIdHash;
    bytes signature;
    address signer;
}

contract BaseTest is Test {
    // store a set of valid creation parameters that can be used in tests
    ValidCreationParams internal validCreate;

    // generate a set of valid creation parameters
    constructor() {
        // generate the wallet for the secret signer
        VmSafe.Wallet memory signer = vm.createWallet(4337);

        // set a random login and hash it
        string memory login = "samus-aran";
        bytes32 loginHash = keccak256(bytes(login));

        // generate a credId hash that corresponds to the login
        bytes32 credIdHash = 0x511deddb8b836e8ced2f5e8a4ee0ac63ae4095b426398cc712aa772a4c68a099;

        // recreate the message to sign
        bytes memory message = abi.encode(0x00, loginHash, signer.publicKeyX, signer.publicKeyY, credIdHash);

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and get the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // save the valid creation parameters
        validCreate = ValidCreationParams({
            pubKeyX: signer.publicKeyX,
            pubKeyY: signer.publicKeyY,
            login: login,
            loginHash: loginHash,
            credIdHash: credIdHash,
            signature: signature,
            signer: signer.addr
        });
    }

    uint256 internal constant P256R1_MAX =
        115_792_089_210_356_248_762_697_446_949_407_573_530_086_143_415_290_314_195_533_631_308_867_097_853_951;

    modifier assumeNoPrecompile(address fuzzedAddress) {
        assumeNotPrecompile(fuzzedAddress);

        _;
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
