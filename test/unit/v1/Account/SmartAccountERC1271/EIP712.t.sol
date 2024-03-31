// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { EIP1271_VALIDATION_SUCCESS, EIP1271_VALIDATION_FAILURE } from "src/v1/Account/SmartAccountEIP1271.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";

struct ValidData {
    uint256 pubX;
    uint256 pubY;
    bytes signature;
    bytes32 message;
    bytes creationAuthData;
}

contract SmartAccountERC1271__EIP712 is BaseTest {
    SmartAccount internal account;
    AccountFactory internal factory;

    ValidData internal data;

    function setUp() external {
        // 1. deploy the webauthn verifier
        WebAuthn256r1Wrapper webauthn = new WebAuthn256r1Wrapper();

        // 2. deploy the mocked version of the entrypoint
        MockEntryPoint entrypoint = new MockEntryPoint();

        // 3. deploy the implementation of the account
        SmartAccount accountImplementation = new SmartAccount(address(entrypoint), address(webauthn));

        // 4. deploy the factory
        address factoryImplementation = address(deployFactoryImplementation(address(accountImplementation)));
        factory = deployFactoryInstance(factoryImplementation, makeAddr("proxy_owner"), SMOOTH_SIGNER.addr);

        // 5. set the signer data for the test
        // This signer has been generated for the needs of this test file. It is a valid signer.
        // The authData here is the authData generated during the creation of the signer.
        data.pubX = 0x6a91f4596b653f97f5c8d13d459be52d35285ee0add61ba5a650df8c45919b25;
        data.pubY = 0x193b85d5270e4995299c9c30af13af4277111cc92c1054da407c623ee69276cd;
        data.creationAuthData =
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97635d00000000fbfc3007154e4ecc8c0b"
            hex"6e020557d7bd0014d0dd31e6291a9162090617691b47ac069a0793fea50102032620012158206a91f4596b653f97f5"
            hex"c8d13d459be52d35285ee0add61ba5a650df8c45919b25225820193b85d5270e4995299c9c30af13af4277111cc92c"
            hex"1054da407c623ee69276cd";

        // 6. set the signature data for the test
        // This signature has been generated for the needs of this test file. It is a valid signature for the signer
        // above. The message here is the hash of the data signed by the signer. It corresponds to the hash calculated
        // during the 712 signature flow using the 712 data (domain/type..) listed below.
        data.signature =
            hex"0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000"
            hex"01205c73f9c19ada2ca3439b6c5eddb70ba1d10b195eadfc22fec16b9bc371b767fb400cc3f92936caf663811c1407"
            hex"ef5471fcece0a020149fa72ac9e8562429e92dc52d483b3e33463d71594a66c1f68a2f92542f29f1f40c3f01470777"
            hex"1714d716000000000000000000000000000000000000000000000000000000000000002549960de5880e8c68743417"
            hex"0f6476605b8fe4aeb9a28632c7995cf3ba831d97631d00000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000f37b2274797065223a22"
            hex"776562617574686e2e676574222c226368616c6c656e6765223a224f7977316f78377668536d46386c495f4c6b2d79"
            hex"6b4e5664364b44584570493144505935536f4977624249222c226f726967696e223a22687474703a2f2f6c6f63616c"
            hex"686f73743a33303030222c2263726f73734f726967696e223a66616c73652c226f746865725f6b6579735f63616e5f"
            hex"62655f61646465645f68657265223a22646f206e6f7420636f6d7061726520636c69656e74446174614a534f4e2061"
            hex"6761696e737420612074656d706c6174652e205365652068747470733a2f2f676f6f2e676c2f796162506578227d00"
            hex"000000000000000000000000";
        data.message = 0xd08956aa42529c201cbeaae40635483d9687ed986304eb34946e5be326ecd5f3;

        // 7. calculate the future address of the account
        address accountFutureAddress = factory.getAddress(data.creationAuthData);

        // 8. deploy the proxy that targets the implementation and set the first signer using the creationAuthData
        bytes memory signature = craftDeploymentSignature(data.creationAuthData, accountFutureAddress);
        account = SmartAccount(payable(factory.createAndInitAccount(data.creationAuthData, signature)));
    }

    function _getDomainSeparator() internal pure returns (bytes32) {
        bytes32 domainTypeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        string memory name = "Passkey Test";
        string memory version = "1";
        uint256 chainId = 1;
        address verifier712 = 0x9999999999999999999999999999999999999999;

        // @DEV: complex types are hashed before being encoded
        return keccak256(
            abi.encode(domainTypeHash, keccak256(bytes(name)), keccak256(bytes(version)), chainId, verifier712)
        );
    }

    function _getStructHash() internal pure returns (bytes32) {
        bytes32 personTypeHash = keccak256("Person(string name,address wallet)");
        string memory name = "qdqdqd.eth";
        address wallet = 0x2222222222222222222222222222222222222222;

        // @DEV: complex types are hashed before being encoded
        return keccak256(abi.encode(personTypeHash, keccak256(bytes(name)), wallet));
    }

    function _calculate712Digest() internal pure returns (bytes32) {
        // 1. calculate the type hashes of the 712 signature OK:
        bytes32 structHash = _getStructHash();

        // 2. calculate the domain separator of the 712 signature OK:
        bytes32 domainSeparator = _getDomainSeparator();

        // 3. calculate the eip712 hash and compare it to the expected one
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _getCredHashFromAuthData(bytes calldata authData) external pure returns (bytes32 credIdHash) {
        (, credIdHash,,) = SignerVaultWebAuthnP256R1.extractSignerFromAuthData(authData);
    }

    function test_CanValidateEIP712Signature() external {
        // it can validate EIP712 signature

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, EIP1271_VALIDATION_SUCCESS);
    }

    function test_ReturnFailureIfNotCorrectType() external {
        // it return failure if not correct type

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. set an invalid prefix to the signature
        bytes memory incorrectSignature =
            abi.encodePacked(bytes1(0x02), truncBytes(data.signature, 1, data.signature.length));

        // 4. verify the signature using the signature and the hash
        // -- it should fail because the signature doesn't have the correct prefix
        bytes4 selector = account.isValidSignature(hash, incorrectSignature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }

    function test_ReturnFailureIfSignerUnknown() external {
        // it return failure if signer unknown

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. manually remove the previously set signer by manipulating proxy's storage
        bytes32 credIdHash = SmartAccountERC1271__EIP712(address(this))._getCredHashFromAuthData(data.creationAuthData);
        bytes32 signerStorageSlot = SignerVaultWebAuthnP256R1.getSignerStartingSlot(credIdHash);
        vm.store(address(account), signerStorageSlot, bytes32(0));

        // 3. verify the signature using the signature and the hash
        // -- it should fail because we didn't set the signer
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }

    function test_RevertIfSignatureNotDecodable() external {
        // it revert if signature not decodable

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. cut the signature to make it invalid
        bytes memory invalidSignature = truncBytes(data.signature, 0, data.signature.length - 32);

        // 4. verify the signature using the signature and the hash
        // -- it should revert as the signature is not decodable
        vm.expectRevert();
        account.isValidSignature(hash, invalidSignature);
    }

    function test_ReturnFailureIfHashIncorrect() external {
        // it return failure if hash incorrect

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. alter the hash to make it incorrect
        bytes32 incorrectHash = keccak256(abi.encodePacked(hash));

        // 4. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(incorrectHash, data.signature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }

    function test_ReturnFailureIfSignatureIncorrect() external {
        // it return failure if signature incorrect

        // 1. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 2. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 3. get dummy bytecode to use as signature
        bytes memory dummySignature = address(this).code;

        // 4. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, dummySignature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }
}

contract MockEntryPoint {
    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
