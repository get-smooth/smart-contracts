// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";

contract Account {
    IEntryPoint public immutable entryPoint;
    address public immutable webAuthnVerifier;
    address public immutable namingService;
    // TODO: why not replace this variable by the recovery of the name service signature
    address private immutable factoryAddress;

    constructor(address _entryPoint, address _webAuthnVerifier, address _namingService) {
        entryPoint = IEntryPoint(_entryPoint);
        webAuthnVerifier = _webAuthnVerifier;
        namingService = _namingService;
        factoryAddress = msg.sender;
    }

    function addFirstSigner(uint256 pubKeyX, uint256 pubKeyY, bytes calldata credId) external {
        // TODO: implement
    }

    function initialize(bytes32 loginHash) external {
        // TODO: implement
    }
}
