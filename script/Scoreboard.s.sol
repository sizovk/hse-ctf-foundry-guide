// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IEthernaut} from "../src/IEthernaut.sol";
import {Levels} from "../src/Levels.sol";

/// Таблица баллов участник×задача. Запуск:
///   forge script script/Scoreboard.s.sol:Scoreboard --rpc-url $SEPOLIA_RPC_URL -vvv
contract Scoreboard is Script {
    function run() external view {
        IEthernaut eth = IEthernaut(vm.envAddress("ETHERNAUT"));
        string[8] memory name = Levels.names();

        uint256 cnt = eth.playersCnt();
        IEthernaut.PlayerData[] memory ps = eth.getPlayers(0, cnt);
        for (uint256 i; i < ps.length; ++i) {
            uint256 best = i;
            for (uint256 j = i + 1; j < ps.length; ++j) {
                if (ps[j].totalScores > ps[best].totalScores) best = j;
            }
            if (best != i) {
                IEthernaut.PlayerData memory tmp = ps[i];
                ps[i] = ps[best];
                ps[best] = tmp;
            }
        }

        string memory legend = "Tasks:";
        for (uint256 j; j < 8; ++j) legend = string.concat(legend, " ", vm.toString(j), "=", name[j]);
        console2.log(legend);

        string memory head = _padR(" rank", 7);
        for (uint256 j; j < 8; ++j) head = string.concat(head, _padL(vm.toString(j), 6));
        head = string.concat(head, _padL("total", 8), "  player");
        console2.log(head);

        for (uint256 i; i < ps.length; ++i) {
            if (ps[i].totalScores == 0) break;
            string memory row = _padR(string.concat(" #", vm.toString(i + 1)), 7);
            for (uint256 j; j < ps[i].scores.length && j < 8; ++j) {
                row = string.concat(row, _padL(vm.toString(ps[i].scores[j]), 6));
            }
            row = string.concat(row, _padL(vm.toString(ps[i].totalScores), 8), "  ", ps[i].nick);
            console2.log(row, ps[i].player);
        }
    }

    function _padL(string memory s, uint256 w) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length >= w) return s;
        bytes memory pad = new bytes(w - b.length);
        for (uint256 i; i < pad.length; ++i) pad[i] = 0x20;
        return string(abi.encodePacked(pad, b));
    }

    function _padR(string memory s, uint256 w) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length >= w) return s;
        bytes memory pad = new bytes(w - b.length);
        for (uint256 i; i < pad.length; ++i) pad[i] = 0x20;
        return string(abi.encodePacked(b, pad));
    }
}
