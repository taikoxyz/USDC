// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {Test, console2} from "forge-std/Test.sol";
import {FiatTokenProxy} from "../src/FiatTokenProxy/centre-tokens/contracts/v1/FiatTokenProxy.sol";
import {FiatTokenV2_1} from "../src/FiatTokenV2_1/centre-tokens/contracts/v2/FiatTokenV2_1.sol";

contract UsdcTest is Test {
    FiatTokenProxy proxyContract;
    FiatTokenV2_1 fiatTokenV2_2;
    address Deployer;
    address proxyOwner; // aka proxy admin too !
    address minterRoleConfigurator; // The one who configures who can mint

    // Dummy for implementation storage setting
    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;

    string constant NAME = "USD Coin";
    string constant SYMBOL = "USDC";
    string constant CURRENCY = "USD";
    uint8 constant DECIMALS = 6;
    address erc20Vault; //"mock" erc20 vault
    address Alice;

    function setUp() public {
        Deployer = vm.addr(0x1);
        proxyOwner = vm.addr(0x2);
        minterRoleConfigurator = vm.addr(0x3);
        erc20Vault = vm.addr(0x4);
        Alice = vm.addr(0x5);

        vm.startPrank(Deployer);
        fiatTokenV2_2 = new FiatTokenV2_1();
        proxyContract = new FiatTokenProxy(address(fiatTokenV2_2));

        //// These values are dummy values because we only rely on the implementation
        //// deployment for delegatecall logic, not for actual state storage.
        fiatTokenV2_2.initialize("", "", "", 0, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS);
        fiatTokenV2_2.initializeV2("");
        fiatTokenV2_2.initializeV2_1(THROWAWAY_ADDRESS);

        //// Do the initial (V1) initialization.
        //// Note that this takes in the master minter contract's address as the master minter.
        //// The master minter contract's owner is a separate address.
        // const proxyAsV2_2 = await FiatTokenV2_2.at(FiatTokenProxy.address);

        vm.stopPrank();

        vm.startPrank(proxyOwner);
        FiatTokenV2_1(address(proxyContract)).initialize(
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            minterRoleConfigurator,
            THROWAWAY_ADDRESS,
            THROWAWAY_ADDRESS,
            proxyOwner
        );

        //// Do the V2 initialization
        // console.log("Initializing V2...");
        FiatTokenV2_1(address(proxyContract)).initializeV2(
            NAME
        );

        // // Do the V2_1 initialization
        // console.log("Initializing V2.1...");
        FiatTokenV2_1(address(proxyContract)).initializeV2_1(
            THROWAWAY_ADDRESS
        );

        vm.stopPrank();

        vm.prank(minterRoleConfigurator, minterRoleConfigurator);
        FiatTokenV2_1(address(proxyContract)).configureMinter(
            erc20Vault,
            type(uint256).max
        );

        // Mint 10 tokens to Alice
        vm.prank(erc20Vault, erc20Vault);
        FiatTokenV2_1(address(proxyContract)).mint(
            Alice,
            10
        );
    }

    function test_erc20_vault_can_mint() public {
        vm.prank(erc20Vault, erc20Vault);
        FiatTokenV2_1(address(proxyContract)).mint(
            Alice,
            5
        );

        assertEq(15, FiatTokenV2_1(address(proxyContract)).balanceOf(
            Alice
        ));
    }

    function test_non_erc20_vault_cannot_mint() public {
        vm.expectRevert("FiatToken: caller is not a minter");
        vm.prank(Alice, Alice);
        FiatTokenV2_1(address(proxyContract)).mint(
            Alice,
            5
        );

        assertEq(10, FiatTokenV2_1(address(proxyContract)).balanceOf(
            Alice
        ));
    }

    function test_erc20_vault_can_burn_own_tokens() public {
        vm.prank(Alice, Alice);
        FiatTokenV2_1(address(proxyContract)).approve(
            erc20Vault,
            10
        );

        vm.prank(Alice, Alice);
        FiatTokenV2_1(address(proxyContract)).transfer(
            erc20Vault,
            10
        );

        assertEq(0, FiatTokenV2_1(address(proxyContract)).balanceOf(
            Alice
        ));

        assertEq(10, FiatTokenV2_1(address(proxyContract)).balanceOf(
            erc20Vault
        ));

        vm.prank(erc20Vault, erc20Vault);
        FiatTokenV2_1(address(proxyContract)).burn(
            10
        );

        assertEq(0, FiatTokenV2_1(address(proxyContract)).balanceOf(
            erc20Vault
        ));
    }

    function test_non_erc20_vault_cannot_burn() public {
        vm.expectRevert("FiatToken: caller is not a minter");
        vm.prank(Alice, Alice);
        FiatTokenV2_1(address(proxyContract)).burn(
            10
        );
    }
}
