// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { BasePaymaster, Ownable, IEntryPoint, UserOperation } from "@eth-infinitism/core/BasePaymaster.sol";

contract DummyPaymaster is BasePaymaster {
    constructor(address entryPoint) BasePaymaster(IEntryPoint(entryPoint)) Ownable(msg.sender) { }

    function _validatePaymasterUserOp(
        UserOperation calldata,
        bytes32,
        uint256
    )
        internal
        override
        returns (bytes memory context, uint256 validationData)
    {
        // accept to pay for all the userops (and return a dummy context)
        return ("", block.timestamp - 1 << (160 + 48));
    }

    function _postOp(PostOpMode, bytes calldata, uint256) internal override {
        // nothing to do -- we don't care about the postOp hook
    }
}
