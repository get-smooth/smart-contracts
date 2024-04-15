// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

// 1 day -- Alchemy's recommended unstake delay
uint256 constant DEFAULT_UNSTAKE_DELAY_SEC = 60 * 60 * 24;

/// @title  PaymasterStake
/// @notice Stake some funds for the paymaster into the entrypoint
contract PaymasterStake is BaseScript {
    function run() public payable broadcast {
        address paymasterAddress = vm.envAddress("PAYMASTER");
        uint256 value = vm.envUint("AMOUNT");
        uint32 unstakeDelaySec = uint32(vm.envOr("UNSTAKE_DELAY_SEC", DEFAULT_UNSTAKE_DELAY_SEC));

        Paymaster paymaster = Paymaster(paymasterAddress);

        // stake some funds for the paymaster into the entrypoint
        paymaster.addStake{ value: value }(unstakeDelaySec);
    }
}
