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
import {Ownable} from "../src/FiatToken/centre-tokens/contracts/v1/Ownable.sol";

// Interface for facilitating the change from regular BridgedERC20 to the 'bridgedUSDC' tokens on L2.
interface IERC20Vault {
    struct CanonicalERC20 {
        uint64 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    function changeBridgedToken(CanonicalERC20 calldata _ctoken, address _btokenNew)
        external
        returns (address btokenOld_);
}

/// For more info see:
/// https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md#token-deployment
contract DeployUSDC is Script {
    FiatTokenProxy proxyContract;
    FiatTokenV2_2 fiatTokenV2_2;

    // L2_OWNER: 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be
    address public owner = vm.envAddress("OWNER");
    // L2_DEPLOYER_ADDRESS:
    address public proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    // L2_DEPLOYER_PRIVATEKEY:
    uint256 public proxyDeployerPrivateKey = vm.envUint("PROXY_DEPLOYER_PRIVATE_KEY");
    // L2_ERC_20_VAULT: 0x1670000000000000000000000000000000000002
    address public erc20VaultL2 = vm.envAddress("ERC_20_VAULT");

    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;

    // Constants, they stays as is.
    string constant NAME = "USD Coin";
    string constant SYMBOL = "USDC";
    string constant CURRENCY = "USD";
    uint8 constant DECIMALS = 6;

    function setUp() public {}

    function run() public {
        require(proxyDeployer != address(0), "proxy deployer is zero");
        require(owner != address(0), "owner is zero");

        vm.startBroadcast(proxyDeployerPrivateKey);

        fiatTokenV2_2 = new FiatTokenV2_2();
        console2.log("Address of impl:", address(fiatTokenV2_2));
        proxyContract = new FiatTokenProxy(address(fiatTokenV2_2));
        console2.log("Address of proxy:", address(proxyContract));

        //// These values are dummy values because we only rely on the implementation
        //// deployment for delegatecall logic, not for actual state storage.
        fiatTokenV2_2.initialize(
            "", "", "", 0, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS, THROWAWAY_ADDRESS
        );
        fiatTokenV2_2.initializeV2("");
        fiatTokenV2_2.initializeV2_1(THROWAWAY_ADDRESS);
        fiatTokenV2_2.initializeV2_2(new address[](0), SYMBOL);

        vm.startBroadcast(proxyDeployerPrivateKey);

        //// Do the V1 initialization
        console2.log("Initializing V1..");
        (, bytes memory retVal) = address(proxyContract).call(
            abi.encodeWithSelector(
                FiatTokenV1.initialize.selector,
                NAME,
                SYMBOL,
                CURRENCY,
                DECIMALS,
                owner,
                THROWAWAY_ADDRESS,
                THROWAWAY_ADDRESS,
                proxyDeployer
            )
        );

        (, retVal) = address(proxyContract).call(
            abi.encodeWithSelector(FiatTokenV1.configureMinter.selector, erc20VaultL2, type(uint256).max)
        );

        (, retVal) = address(proxyContract).call(abi.encodeWithSelector(FiatTokenV2.initializeV2.selector, NAME));

        (, retVal) = address(proxyContract).call(
            abi.encodeWithSelector(FiatTokenV2_1.initializeV2_1.selector, THROWAWAY_ADDRESS)
        );

        (, retVal) = address(proxyContract).call(
            abi.encodeWithSelector(FiatTokenV2_2.initializeV2_2.selector, new address[](0), SYMBOL)
        );

        (, retVal) = address(proxyContract).call(
            abi.encodeWithSelector(Ownable.transferOwnership.selector, owner)
        );

        vm.stopBroadcast();
    }
}
