// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {Script, console2} from "forge-std/Script.sol";
import {FiatTokenProxy} from "../src/FiatTokenProxy/centre-tokens/contracts/v1/FiatTokenProxy.sol";
import {FiatTokenV2_1} from "../src/FiatTokenV2_1/centre-tokens/contracts/v2/FiatTokenV2_1.sol";

contract DeployUSDCScript is Script {
    FiatTokenProxy proxyContract;
    FiatTokenV2_1 fiatTokenV2_2;

    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address public proxyOwner = vm.envAddress("OWNER");
    address public minterConfigurator = vm.envAddress("MINTING_ADMIN");
    address public erc20Vault = vm.envAddress("ERC20_VAULT");


    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;

    string constant NAME = "USD Coin";
    string constant SYMBOL = "USDC";
    string constant CURRENCY = "USD";
    uint8 constant DECIMALS = 6;

    function setUp() public {}

    function run() public {
        require(proxyOwner != address(0), "proxy owner is zero");
        require(minterConfigurator != address(0), "minter admin is zero");
        require(erc20Vault != address(0), "erc20Vault is zero");

        vm.startBroadcast(deployerPrivateKey);
        fiatTokenV2_2 = new FiatTokenV2_1();
        proxyContract = new FiatTokenProxy(address(fiatTokenV2_2));

        //// These values are dummy values because we only rely on the implementation
        //// deployment for delegatecall logic, not for actual state storage.
        fiatTokenV2_2.initialize("", "", "", 0, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS);
        fiatTokenV2_2.initializeV2("");
        fiatTokenV2_2.initializeV2_1(THROWAWAY_ADDRESS);

        //// Do the V1 initialization
        // console.log("Initializing V1..
        FiatTokenV2_1(address(proxyContract)).initialize(
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            minterConfigurator,
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
        
        vm.stopBroadcast();

        vm.prank(minterConfigurator, minterConfigurator);
        FiatTokenV2_1(address(proxyContract)).configureMinter(
            erc20Vault,
            type(uint256).max
        );
    }
}
