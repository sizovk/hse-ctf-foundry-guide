// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Интерфейс платформы Ethernaut (Sepolia).
interface IEthernaut {
    struct PlayerData {
        address player;
        string nick;
        uint256 totalScores;
        uint256[] scores;
    }

    event LevelInstanceCreatedLog(address indexed player, address instance);

    function register(string calldata nick) external;
    function createLevelInstance(address level) external payable;
    function submitLevelInstance(address payable instance) external;

    function startTs() external view returns (uint256);
    function nicks(address player) external view returns (string memory);
    function isBusyNick(string calldata nick) external view returns (bool);
    function scores(address player, address level) external view returns (uint256);
    function totalScores(address player) external view returns (uint256);
    function registerTimestamp(address player) external view returns (uint256);
    function playersCnt() external view returns (uint256);
    function players(uint256 i) external view returns (address);
    function registeredLevels(address level) external view returns (bool);
    function registeredLevelsArray(uint256 i) external view returns (address);
    function getPlayers(uint256 offset, uint256 limit) external view returns (PlayerData[] memory);
}
