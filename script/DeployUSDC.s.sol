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

/// For more info see:
/// https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md#token-deployment
contract DeployUSDC is Script {
    FiatTokenProxy proxyContract;
    FiatTokenV2_1 fiatTokenV2_1;

    address public masterMinter = vm.envAddress("MASTER_MINTER");
    address public proxyOwner = vm.envAddress("PROXY_OWNER");

    uint256 public proxyOwnerPrivateKey = vm.envUint("PROXY_OWNER_PRIVATE_KEY");
    //Proxy owner cannot call impl contract
    uint256 public initializerPrivateKey = vm.envUint("INITIALIZER_PRIVATE_KEY");

    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;

    // Constants, they stays as is.
    string constant NAME = "USD Coin";
    string constant SYMBOL = "USDC";
    string constant CURRENCY = "USD";
    uint8 constant DECIMALS = 6;

    function setUp() public {}

    function run() public {
        require(proxyOwner != address(0), "proxy owner is zero");
        require(masterMinter != address(0), "minter admin is zero");
        
        vm.startBroadcast(proxyOwnerPrivateKey);

        fiatTokenV2_1 = new FiatTokenV2_1();
        console2.log("Address of impl:", address(fiatTokenV2_1));
        proxyContract = new FiatTokenProxy(address(fiatTokenV2_1));
        console2.log("Address of proxy:", address(proxyContract));

        //// These values are dummy values because we only rely on the implementation
        //// deployment for delegatecall logic, not for actual state storage.
        fiatTokenV2_1.initialize("", "", "", 0, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS);
        fiatTokenV2_1.initializeV2("");
        fiatTokenV2_1.initializeV2_1(THROWAWAY_ADDRESS);

        vm.stopBroadcast();

        vm.startBroadcast(initializerPrivateKey);
        //// Do the V1 initialization
        console2.log("Initializing V1..");
        FiatTokenV2_1(address(proxyContract)).initialize(
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            masterMinter,
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
    }
}