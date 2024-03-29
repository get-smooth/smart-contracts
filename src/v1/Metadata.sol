// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

library Metadata {
    string internal constant VERSION = "1.0.0";

    // default address -- entrypoint version: 0.6.0
    address internal constant ENTRYPOINT_ADDRESS = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    // entrypoint version: 0.7.0
    address internal constant ENTRYPOINT_ADDRESS_V0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /// @notice Get the version of the entrypoint to use
    /// @dev The current default version of the entrypoint is 0.6.0
    function entrypoint() internal pure returns (address) {
        return ENTRYPOINT_ADDRESS;
    }
}
