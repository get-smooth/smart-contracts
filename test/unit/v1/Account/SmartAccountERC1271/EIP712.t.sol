// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { EIP1271_VALIDATION_SUCCESS, EIP1271_VALIDATION_FAILURE } from "src/v1/Account/SmartAccountEIP1271.sol";
import { BaseTest } from "test/BaseTest.sol";

struct ValidData {
    uint256 pubX;
    uint256 pubY;
    bytes signature;
    bytes32 message;
}

contract SmartAccountERC1271__EIP712 is BaseTest {
    SmartAccount internal account;
    address internal factory;

    ValidData internal data;

    function setUp() external {
        // 1. deploy the webauthn verifier
        WebAuthn256r1Wrapper webauthn = new WebAuthn256r1Wrapper();

        // 2. deploy the mocked version of the entrypoint
        MockEntryPoint entrypoint = new MockEntryPoint();

        // 3. deploy a new instance of the account
        factory = makeAddr("factory");
        vm.prank(factory);
        account = new SmartAccount(address(entrypoint), address(webauthn));

        // 4. set the valid variables
        data.pubX = 0xab731bacd51a82abd186f009a33b52cd3cdbb52ad4b083f8582289b740c3ecf1;
        data.pubY = 0xba2315660d301f692a762634b79d8c95d6604727787adfa64d17ee630b66afc5;
        data.signature = hex"010000000000000000000000000000000000000000000000000000000000000000"
            hex"000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000"
            hex"00000000000000000000000000000000000120a56040fc3340115374884d1b603c866f49109558d3c86ea5ea"
            hex"098979eb54b64520680fb45145a72cba76f4b9753bde29974e161395677f14a0a15f18aa997f4e35ea369a49"
            hex"a3cdddebc026e502324612596a2be266e480605620839d7cefae440000000000000000000000000000000000"
            hex"00000000000000000000000000002549960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba83"
            hex"1d97631d00000000000000000000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000f37b2274797065223a22776562617574686e2e676574"
            hex"222c226368616c6c656e6765223a224f7977316f78377668536d46386c495f4c6b2d796b4e5664364b445845"
            hex"70493144505935536f4977624249222c226f726967696e223a22687474703a2f2f6c6f63616c686f73743a33"
            hex"303030222c2263726f73734f726967696e223a66616c73652c226f746865725f6b6579735f63616e5f62655f"
            hex"61646465645f68657265223a22646f206e6f7420636f6d7061726520636c69656e74446174614a534f4e2061"
            hex"6761696e737420612074656d706c6174652e205365652068747470733a2f2f676f6f2e676c2f796162506578"
            hex"227d00000000000000000000000000";
        data.message = 0xd08956aa42529c201cbeaae40635483d9687ed986304eb34946e5be326ecd5f3;
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

    function test_CanValidateEIP712Signature() external {
        // it can validate EIP712 signature

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 3. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 4. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 5. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_SUCCESS));
    }

    function _modifiySignaturePrefix(bytes calldata signature, uint8 prefix) external pure returns (bytes memory) {
        return abi.encodePacked(prefix, signature[1:]);
    }

    function test_ReturnFailureIfNotCorrectType() external {
        // it return failure if not correct type

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 3. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 4. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 5. modify the prefix of the signature
        bytes memory incorrectSignature =
            SmartAccountERC1271__EIP712(address(this))._modifiySignaturePrefix(data.signature, 0x02);

        // 6. verify the signature using the signature and the hash
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

        // 3. verify the signature using the signature and the hash
        // -- it should fail because we didn't set the signer
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }

    function test_RevertIfSignatureNotDecodable() external {
        // it revert if signature not decodable

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 3. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 4. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 5. cut the signature to make it invalid
        bytes memory invalidSignature = _truncBytes(data.signature, 0, data.signature.length - 32);

        // 6. verify the signature using the signature and the hash
        // -- it should revert as the signature is not decodable
        vm.expectRevert();
        account.isValidSignature(hash, invalidSignature);
    }

    function test_ReturnFailureIfHashIncorrect() external {
        // it return failure if hash incorrect

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 3. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 5. alter the hash to make it incorrect
        bytes32 incorrectHash = keccak256(abi.encodePacked(hash));

        // 6. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 7. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(incorrectHash, data.signature);
        assertEq(selector, bytes4(EIP1271_VALIDATION_FAILURE));
    }

    function test_ReturnFailureIfSignatureIncorrect() external {
        // it return failure if signature incorrect

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip712 hash and compare it to the expected one
        bytes32 digest = _calculate712Digest();

        // 3. hash the digest signed by the user
        // @DEV: The EIP1271 expect the signature is tested against the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(digest));

        // 4. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 5. get dummy bytecode to use as signature
        bytes memory dummySignature = address(this).code;

        // 5. verify the signature using the signature and the hash
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
