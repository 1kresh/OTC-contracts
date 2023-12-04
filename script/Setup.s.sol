// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {OTC} from "../src/OTC.sol";
import {PublicKeysRegistry} from "../src/PublicKeysRegistry.sol";

// forge script script/Setup.s.sol:SetupScript --via-ir
contract SetupScript is Script {
    function setUp() public {}

    function run() public {
        uint256 forkId = vm.createFork(vm.envString("SEPLOIA_RPC_URL"));
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        address zerox = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
        address[] memory tokens = new address[](2);
        tokens[0] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        tokens[1] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

        vm.selectFork(forkId);
        vm.startBroadcast(uint256(vm.envBytes32("PRIVATE_KEY")));
        
        OTC otc = new OTC(permit2, zerox);
        for (uint256 i; i < tokens.length; ++i) {
            otc.addToken(tokens[i]);
        }
        // PublicKeysRegistry registry = new PublicKeysRegistry();

        vm.stopBroadcast();
    }
}
