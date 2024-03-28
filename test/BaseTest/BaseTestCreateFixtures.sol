// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test, stdJson } from "forge-std/Test.sol";

struct FixturesUser {
    string id;
    string name;
    string displayName;
}

struct FixturesSignature {
    bytes value;
    bytes challenge;
    uint256 r;
    uint256 s;
}

struct FixturesSigner {
    bytes credId;
    uint256 pubX;
    uint256 pubY;
}

struct FixturesResponse {
    bytes attestationObject;
    bytes clientDataJSON;
    bytes authData;
}

struct CreateFixtures {
    uint256 id;
    FixturesUser user;
    FixturesSignature signature;
    FixturesSigner signer;
    FixturesResponse response;
}

/// @title BaseTestCreateFixtures
/// @notice This contract is in charge of loading the data from the `fixtures.create.json` file
/// @dev The data is for testing purposes only. Take a look to the README close to the file to understand where the data
///      comes from
contract BaseTestCreateFixtures is Test {
    using stdJson for string;

    CreateFixtures internal createFixtures;

    /// @notice Modifier to laod the create fixtures
    /// @dev    Add this modifier to the `setUp` function in our test contract to make sure the fixtures are ready to be
    ///         used in your tests
    modifier setUpCreateFixture() {
        loadCreateFixture();
        _;
    }

    function loadCreateFixture() internal {
        return loadCreateFixture(0);
    }

    // TODO: split into two functions: `StoreX` and `LoadX`.
    //       `LoadX` will return a fixtures
    //       `StoreX` will call the `LoadX` function and store the result in the storage

    /// @notice Load a specific createFixture data from the `fixtures.create.json` file and store the in the
    ///         storage variable `createFixtures`. The data can be accessed using the `createFixtures` storage variable.
    /// @dev    This function is excluded fron the gas metering to avoid the gas cost of reading the file, manipulating
    ///         the data and storing it to the storage. However, keep in mind that the gas cost of reading the data is
    ///         still included in the gas report of your test.
    ///         One of the idea to avoid this is to create getters function that will be in charge of loading some part
    ///         of the data and use them in your tests. Those getter function will be excluded from the gas metering
    ///         using the `noGasMetering` modifier.
    ///         The data are loaded inside blocks to avoid stack too deep error.
    /// @param  seed The seed to use to load the fixture. This number will be bounded to the number of fixtures
    function loadCreateFixture(uint256 seed) internal noGasMetering {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fixtures/fixtures.create.json");
        string memory json = vm.readFile(path);

        uint256 id;

        // if the seed provided is not 0, bound the provided seed to the number of fixtures
        if (seed != 0) {
            uint256 nbOfCreateFixtures = json.readUint(".length");
            id = seed % nbOfCreateFixtures;
        }

        string memory fixturesId = string.concat(".data[", vm.toString(id), "]");

        FixturesUser memory user;
        FixturesSignature memory signature;
        FixturesSigner memory signer;
        FixturesResponse memory response;

        // load and store the user data
        {
            string memory userId = json.readString(string.concat(fixturesId, ".user.id"));
            string memory userName = json.readString(string.concat(fixturesId, ".user.name"));
            string memory displayName = json.readString(string.concat(fixturesId, ".user.displayName"));

            user = FixturesUser({ id: userId, name: userName, displayName: displayName });
        }

        // load and store the signature data
        {
            bytes memory value =
                json.readBytes(string.concat(fixturesId, ".responseDecoded.AttestationObject.attStmt.sig"));
            uint256 r = json.readUint(string.concat(fixturesId, ".responseDecoded.AttestationObject.attStmt.r"));
            uint256 s = json.readUint(string.concat(fixturesId, ".responseDecoded.AttestationObject.attStmt.s"));
            bytes memory challenge =
                json.readBytes(string.concat(fixturesId, ".responseDecoded.ClientDataJSON.challenge"));

            signature = FixturesSignature({ value: value, challenge: challenge, r: r, s: s });
        }

        // load and store the signer data
        {
            bytes memory credId =
                json.readBytes(string.concat(fixturesId, ".responseDecoded.AttestationObject.authData.credentialId"));
            uint256 pubX =
                json.readUint(string.concat(fixturesId, ".responseDecoded.AttestationObject.authData.pubKeyX"));
            uint256 pubY =
                json.readUint(string.concat(fixturesId, ".responseDecoded.AttestationObject.authData.pubKeyY"));

            signer = FixturesSigner({ credId: credId, pubX: pubX, pubY: pubY });
        }

        // load and store the response data
        {
            bytes memory attestationObject = json.readBytes(string.concat(fixturesId, ".response.attestationObject"));
            bytes memory clientDataJSON = json.readBytes(string.concat(fixturesId, ".response.clientDataJSON"));
            bytes memory authData = json.readBytes(string.concat(fixturesId, ".response.authData"));

            response = FixturesResponse({
                attestationObject: attestationObject,
                clientDataJSON: clientDataJSON,
                authData: authData
            });
        }

        // create the fixture and store it in the storage
        // forgefmt: disable-next-item
        createFixtures = CreateFixtures({
            id: id,
            user: user,
            signature: signature,
            signer: signer,
            response: response
        });
    }
}
