// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    // Current universal address of the 4337 entrypoint
    address internal constant DEFAULT_ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @notice this modifier can be used as a generic broadcast solution. It will automatically either:
    ///        - use the private key provided as an environment variable to broadcast
    ///        - or starts the hardware wallet flow if the correct flags are provided and the env variable is not set
    modifier broadcast() {
        uint256 privateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        privateKey != 0 ? vm.startBroadcast(privateKey) : vm.startBroadcast();

        _;

        vm.stopBroadcast();
    }
}
