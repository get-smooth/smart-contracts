// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "../Base.s.sol";

struct Version {
    uint256 full;
    uint256 major;
    uint256 minor;
    uint256 patch;
}

/// @title  SmartAccountDeploy
/// @notice Deploy the implementation of the smart-account
contract SmoothVersionScan is BaseScript {
    function getMajorVersion(uint256 fullVersion) internal pure returns (uint256) {
        if (fullVersion < 1_000_000) return 0;
        return fullVersion / 1_000_000;
    }

    // Extract the common version
    function getMinorVersion(uint256 fullVersion) internal pure returns (uint256) {
        if (fullVersion < 1000) return 0;
        return (fullVersion / 1000) % 1000;
    }

    // Extract the minor version
    function getPatchVersion(uint256 fullVersion) internal pure returns (uint256) {
        return fullVersion % 1000;
    }

    function run() external returns (Version memory version) {
        address smoothContract = vm.envAddress("SMOOTH_CONTRACT");

        // 1. get full version of the contract
        (bool success, bytes memory data) = smoothContract.call(abi.encodeWithSignature("version()"));
        require(success, "Failed to fetch version");
        uint256 fullVersion = abi.decode(data, (uint256));

        // 2. parse major/minor/patch versions of the contract
        uint256 majorVersion = getMajorVersion(fullVersion);
        uint256 minorVersion = getMinorVersion(fullVersion);
        uint256 patchVersion = getPatchVersion(fullVersion);

        // 3. Run the script using the entrypoint address
        version = Version({ full: fullVersion, major: majorVersion, minor: minorVersion, patch: patchVersion });
    }
}
