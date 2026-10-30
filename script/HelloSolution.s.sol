// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IEthernaut} from "../src/IEthernaut.sol";

interface IHello {
    function setHello(address target) external returns (bool);
    function done() external view returns (bool);
}

contract Greeter {
    function sayHi() external pure returns (bytes memory) {
        return bytes("HelloFromHSE");
    }
}

contract HelloSolution is Script {
    function run() external {
        IEthernaut eth = IEthernaut(vm.envAddress("ETHERNAUT"));
        address level = vm.envAddress("LEVEL");
        address payable instance = payable(vm.envAddress("INSTANCE"));
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        _solve(instance);
        eth.submitLevelInstance(instance);
        vm.stopBroadcast();

        console2.log("score =", eth.scores(vm.addr(pk), level));
    }

    function _solve(address instance) internal {
        IHello(instance).setHello(address(new Greeter()));
        require(IHello(instance).done(), "not solved");
    }
}
