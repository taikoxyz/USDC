// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {Script, console2} from "forge-std/Script.sol";
import {FiatTokenProxy} from "../src/FiatTokenProxy/centre-tokens/contracts/v1/FiatTokenProxy.sol";
import {FiatTokenV1} from "../src/FiatToken/centre-tokens/contracts/v1/FiatTokenV1.sol";
import {FiatTokenV2} from "../src/FiatToken/centre-tokens/contracts/v2/FiatTokenV2.sol";
import {FiatTokenV2_1} from "../src/FiatToken/centre-tokens/contracts/v2/FiatTokenV2_1.sol";
import {FiatTokenV2_2} from "../src/FiatToken/centre-tokens/contracts/v2/FiatTokenV2_2.sol";


// Interface for facilitating the change from regular BridgedERC20 to the 'bridgedUSDC' tokens on L2.
interface IERC20Vault {

    struct CanonicalERC20 {
        uint64 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    function changeBridgedToken(
        CanonicalERC20 calldata _ctoken,
        address _btokenNew
    )
        external
        returns (address btokenOld_);
}

/// For more info see:
/// https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md#token-deployment
contract DeployUSDC is Script {
    FiatTokenProxy proxyContract;
    FiatTokenV2_2 fiatTokenV2_2;

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

    // Variables related to changeBridgedToken()
    //Private key, who is allowed to call changeBridgedToken()
    uint256 public erc20VaultChangeBridgePrivateyKey = vm.envUint("CHANGE_BRIDGE_TOKEN_PRIVATE_KEY");
    address public erc20VaultL2 = vm.envAddress("ERC_20_VAULT");
    address public constant USDC_ON_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {}

    function run() public {
        require(proxyOwner != address(0), "proxy owner is zero");
        require(masterMinter != address(0), "minter admin is zero");
        
        vm.startBroadcast(proxyOwnerPrivateKey);

        fiatTokenV2_2 = new FiatTokenV2_2();
        console2.log("Address of impl:", address(fiatTokenV2_2));
        proxyContract = new FiatTokenProxy(address(fiatTokenV2_2));
        console2.log("Address of proxy:", address(proxyContract));

        //// These values are dummy values because we only rely on the implementation
        //// deployment for delegatecall logic, not for actual state storage.
        fiatTokenV2_2.initialize("", "", "", 0, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS);
        fiatTokenV2_2.initializeV2("");
        fiatTokenV2_2.initializeV2_1(THROWAWAY_ADDRESS);
        fiatTokenV2_2.initializeV2_2(new address[](0), SYMBOL);

        vm.stopBroadcast();

        vm.startBroadcast(initializerPrivateKey);
        //// Do the V1 initialization
        console2.log("Initializing V1..");
        (, bytes memory retVal) = address(proxyContract).call(abi.encodeWithSelector(
            FiatTokenV1.initialize.selector, 
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            masterMinter,
            THROWAWAY_ADDRESS,
            THROWAWAY_ADDRESS,
            proxyOwner
            )
        );

        (, retVal) = address(proxyContract).call(abi.encodeWithSelector(
            FiatTokenV2.initializeV2.selector, 
            NAME
            )
        );

        (, retVal) = address(proxyContract).call(abi.encodeWithSelector(
            FiatTokenV2_1.initializeV2_1.selector, 
            THROWAWAY_ADDRESS
            )
        );

        (, retVal) = address(proxyContract).call(abi.encodeWithSelector(
            FiatTokenV2_2.initializeV2_2.selector, 
            new address[](0),
            SYMBOL
            )
        );
        
        vm.stopBroadcast();


        vm.startBroadcast(initializerPrivateKey);
        require(erc20VaultL2 != address(0), "invalid params");

        IERC20Vault vault = IERC20Vault(erc20VaultL2);
        address currBridgedtoken = vault.canonicalToBridged(1, USDC_ON_ETHEREUM);
        console2.log("current btoken for usdc:", currBridgedtoken);

        vault.changeBridgedToken(
            IERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: USDC_ON_ETHEREUM,
                decimals: 6,
                symbol: "USDC",
                name: "USD Coin"
            }),
            address(proxyContract)
        );
        if (vault.paused()) {
            vault.unpause();
        }
        vm.stopBroadcast();

        address newBridgedToken = vault.canonicalToBridged(1, USDC_ON_ETHEREUM);
        console2.log("new btoken for usdc:", newBridgedToken);

        require(address(proxyContract) == newBridgedToken, "unexpected result");

        vm.stopBroadcast();
    }
}