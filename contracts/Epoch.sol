pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Epoch is Ownable {
    using SafeMath for uint256;

    uint256 private period;
    uint256 private startTime;
    uint256 private lastExecutedAt;

    /* ========== CONSTRUCTOR ========== */

    constructor(uint256 _period) public {
        period = _period;
    }

    /* ========== Modifier ========== */

    modifier checkStartTime {
        require(startTime != 0, "Epoch: not started yet");
        require(block.timestamp >= startTime, "Epoch: not started yet");

        _;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(
            _startTime > block.timestamp,
            "Epoch: invalid start time, should be later than now"
        );
        startTime = _startTime;
        lastExecutedAt = startTime;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // epoch
    function getLastEpoch() public view returns (uint256) {
        return lastExecutedAt.sub(startTime).div(period);
    }

    function getCurrentEpoch() public view returns (uint256) {
        return Math.max(startTime, block.timestamp).sub(startTime).div(period);
    }

    // params
    function getPeriod() public view returns (uint256) {
        return period;
    }

    function getStartTime() public view returns (uint256) {
        return startTime;
    }

    /* ========== GOVERNANCE ========== */

    // function setPeriod(uint256 _period) external onlyOwner {
    //     period = _period;
    // }

    // ========== MUTATE FUNCTIONS ==========

    function updateEpoch() internal {
        lastExecutedAt = block.timestamp;
    }
}
