// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { OwnableUpgradeable, Initializable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Metadata } from "src/v1/Metadata.sol";
import { ITransparentUpgradeableProxy, ProxyAdmin } from "src/v1/Proxy/TransparentProxy.sol";

bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

contract AccountFactory__Upgradeable is BaseTest {
    address internal originalImplementation;
    address internal newFactoryImplementation;
    address internal proxyOwner;
    address internal factoryOwner;

    function setUp() external {
        address accountImplementation = makeAddr("account");

        // 1. deploy the implementation of the factory and one instance
        originalImplementation = address(new AccountFactory(accountImplementation));

        // 2. deploy a second implementation of the factory
        newFactoryImplementation = address(new AccountFactoryV2(accountImplementation));

        // 3. set the owner of the proxy and the owner of the factory
        proxyOwner = makeAddr("proxy-owner");
        factoryOwner = makeAddr("factory-owner");
    }

    function test_CanBeUpgradedToAnotherImplementation() external {
        // it can be upgraded to another implementation

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 3. check the version is the expected one
        uint256 initialVersion = factory.version();
        assertEq(initialVersion, Metadata.VERSION);

        // 4. upgrade the factory to the new implementation
        vm.prank(proxyOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(factory)),
            newFactoryImplementation,
            abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 2)
        );

        // 5. check the version has been updated
        assert(factory.version() > initialVersion);
    }

    function test_DeployAProxyAdminContractOnInitAndStoreTheAdmin() external {
        // it deploy a ProxyAdmin contract on init and store the admin

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        address proxyAdmin = abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address));

        // 3. assert that the ProxyAdmin contract is set
        assertNotEq(proxyAdmin, address(0));

        // 3. assert the owner of the ProxyAdmin contract is the proxy owner
        assertEq(OwnableUpgradeable(proxyAdmin).owner(), proxyOwner);
    }

    function test_AllowsTheAdminToChangeTheAdmin() external {
        // it allows the admin to change the admin

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 3. upgrade the factory to the new implementation
        address newProxyOwner = makeAddr("new-proxy-owner");
        vm.prank(proxyOwner);
        proxyAdmin.transferOwnership(newProxyOwner);

        // 4. check the owner of the ProxyAdmin contract has been updated
        assertEq(proxyAdmin.owner(), newProxyOwner);
    }

    function test_AllowsTheAdminToUpgradeTheProxyUsingFallback() external {
        // it allows the admin to upgrade the proxy using fallback

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 3. upgrade the factory instance to point to a new factory implementation using fallback
        vm.prank(address(proxyAdmin));
        (bool isSuccess,) = address(factory).call(
            abi.encodeWithSelector(
                // @DEV: this exact selector must be used to trigger the upgrade flow
                ITransparentUpgradeableProxy.upgradeToAndCall.selector,
                newFactoryImplementation,
                abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 2)
            )
        );

        // 4. check the call has been successful and the implementation has been updated
        assertTrue(isSuccess);
        assert(factory.version() > Metadata.VERSION);
    }

    function test_DelegateNonAdminCallsCorrectly() external setUpCreateFixture {
        // it delegate non admin calls correctly

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. call the calculate address function presents in the account factory contract
        //    this is expected to work because the caller is not the admin
        vm.prank(makeAddr("non-admin"));
        address calculatedAddress = factory.getAddress(createFixtures.response.authData);
        assertNotEq(calculatedAddress, address(0));
    }

    function test_RevertIfReinitializerIsEqualOrBelow() external {
        // it revert if reinitializer is equal or below

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 3. try to upgrade the factory to a implementation with the same version -- must revert
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(proxyOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(factory)),
            newFactoryImplementation,
            abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 1)
        );

        // 3. try to upgrade the factory to a implementation with a lower version -- must revert
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(proxyOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(factory)),
            newFactoryImplementation,
            abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 0)
        );
    }

    function test_DoNotAlterTheSignerAddress() external {
        // it do not alter the signer address

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 3. fetch the current owner
        address preOwner = factory.owner();

        // 4. upgrade the factory to the new implementation
        vm.prank(proxyOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(factory)),
            newFactoryImplementation,
            abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 2)
        );

        // 5. fetch the new owner
        address postOwner = factory.owner();

        // 6. check the address has not changed
        assertEq(preOwner, postOwner);
    }

    function test_DoNotAlterTheCREATE2FormulaOnUpgrade() external setUpCreateFixture {
        // it do not alter the CREATE2 formula on upgrade

        // 1. deploy a new factory instance
        AccountFactory factory = deployFactoryInstance(originalImplementation, proxyOwner, factoryOwner);

        // 2. calculate account address based on valid authData
        address preCalculatedAddress = factory.getAddress(createFixtures.response.authData);

        // 3. get the address of the ProxyAdmin contract automatically deployed by the proxy
        ProxyAdmin proxyAdmin =
            ProxyAdmin(abi.decode(abi.encodePacked(vm.load(address(factory), ADMIN_SLOT)), (address)));

        // 4. upgrade the factory to the new implementation
        vm.prank(proxyOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(factory)),
            newFactoryImplementation,
            abi.encodeWithSelector(AccountFactoryV2.initialize.selector, 2)
        );

        // 5. calculate again account address based on valid authData
        address postCalculatedAddress = factory.getAddress(createFixtures.response.authData);

        // 6. check the address has not changed
        assertEq(preCalculatedAddress, postCalculatedAddress);
    }
}

contract AccountFactoryV2 is AccountFactory {
    constructor(address accountImplementation) AccountFactory(accountImplementation) { }

    function version() external pure virtual override returns (uint256) {
        return Metadata.VERSION + 1_000_000;
    }

    // solhint-disable-next-line no-empty-blocks
    function initialize(uint64 _version) public reinitializer(_version) { }
}
