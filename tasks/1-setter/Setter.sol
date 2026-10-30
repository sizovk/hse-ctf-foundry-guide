// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Setter {

    address public reader;
    uint private MAGIC_NUMBER;
    uint public YOUR_NUMBER;

    constructor(address _reader, uint num) {
        reader = _reader;
        MAGIC_NUMBER = num;
    }

    modifier onlyReader {
        require(msg.sender == reader);
        _;
    }

    function getNum() external view onlyReader returns (uint) {
        return MAGIC_NUMBER;
    }

    function setYourNum(uint num) external {
        YOUR_NUMBER = num;
    }

    function solved() external view returns (bool) {
        return YOUR_NUMBER == MAGIC_NUMBER;
    }
}
