pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Interfaces.sol";

contract FakeAuction is Context, Ownable {
    using SafeMath for uint256;
    
    IUnicToken internal _unicToken;

    uint256 public constant DAILY_MINT_CAP = 2_500_000_000_000_000_000_000_000;
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 public constant PERCENT_100 = 10**18;

    uint256[] public mintTimes;
    mapping(uint256 => mapping(address => uint256)) public dailyStakedUnic;
    mapping(uint256 => mapping(address => uint256)) public dailyParticipatedETH;
    mapping(uint256 => uint256) public dailyTotalStakedUnic;
    mapping(uint256 => uint256) public dailyTotalParticipatedETH;

    constructor(address unicTokenAddress, uint256 mintTime) public {
        require(unicTokenAddress != ZERO_ADDRESS, "ZERO ADDRESS");
        _unicToken = IUnicToken(unicTokenAddress);
        setLastMintTime(mintTime);
    }

    function getMintTimestamp(uint256 index) external view returns (uint256) {
        return mintTimes[index];
    }

    function canUnlockTokens(uint256 mintTime) external view returns (uint256) {
        return dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getLastMintTime() public view returns (uint256) {
        return mintTimes[mintTimes.length - 1];
    }

    function getMintTimesLength() public view returns (uint256) {
        return mintTimes.length;
    }

    function setLastMintTime(uint256 mintTime) internal {
        mintTimes.push(mintTime);
    }

    function getParticipatedETHAmount(uint256 mintTime) public view returns (uint256) {
        return dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getDailyTotalStakedUnic(uint256 stakeTime) external view returns (uint256) {
        return dailyTotalStakedUnic[stakeTime];
    }

    function getStakedUnic(uint256 stakeTime) external view returns (uint256) {
        return dailyStakedUnic[stakeTime][_msgSender()];
    }

    function getTotalParticipateAmount() external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < mintTimes.length; i++) {
            totalEth = totalEth.add(dailyParticipatedETH[mintTimes[i]][_msgSender()]);
        }
        return totalEth;
    }

    function startNextRound(uint256 startTime) internal {
        setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }

    function participate(uint256 callTime) external payable {
        require(msg.value > 0, "Insufficient participation");
        if (getLastMintTime().add(86400) <= callTime) {
            uint256 newLastMintTime = getLastMintTime().add(((callTime.sub(getLastMintTime())).div(86400)).mul(86400));
            startNextRound(newLastMintTime);
        }
        uint256 lastMintTime = getLastMintTime();
        dailyTotalParticipatedETH[lastMintTime] = dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        dailyParticipatedETH[lastMintTime][_msgSender()] = dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
    }

    function unlockTokens(uint256 mintTime) public {
        require(dailyParticipatedETH[mintTime][_msgSender()] > 0, "Nothing to unlock");
        // require(mintTime.add(86400) < now);
        uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout));
    }

    function stake(uint256 amount, uint256 callTime) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime;
        if (getLastMintTime().add(86400) <= callTime) {
            stakeTime = getLastMintTime().add(((callTime.sub(getLastMintTime())).div(86400)).mul(86400));
        } else {
            stakeTime = getLastMintTime();
        }
        dailyTotalStakedUnic[stakeTime] = dailyTotalStakedUnic[stakeTime].add(amount);
        dailyStakedUnic[stakeTime][_msgSender()] = dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    uint256 public test;

    function unStake(uint256 stakeTime, uint256 callTime) external {
        require(dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        uint256 i;
        uint256 totalStakeEarnings;
        if (stakeTime.add(86400) < callTime) {
            for (i = stakeTime; i <= callTime && i < stakeTime.add(86400 * 100); i += 86400) {
                if (dailyTotalParticipatedETH[i] > 0) {
                    uint256 stakeEarningsPercent = dailyStakedUnic[stakeTime][_msgSender()]
                        .mul(PERCENT_100)
                        .div(dailyTotalStakedUnic[i] > 0 ? dailyTotalStakedUnic[i].add(stakeTime != i ? dailyTotalStakedUnic[stakeTime] : 0) : dailyTotalStakedUnic[stakeTime])
                        .mul(100)
                        .div(PERCENT_100);
                    uint256 stakersETHShare = dailyTotalParticipatedETH[i] - dailyTotalParticipatedETH[i].div(20);
                    totalStakeEarnings = totalStakeEarnings.add(
                        stakersETHShare
                            .mul(PERCENT_100)
                            .div(100)
                            .mul(stakeEarningsPercent)
                            .div(PERCENT_100)
                    );
                }
            }
        }
        test = totalStakeEarnings;
        delete dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(totalStakeEarnings);
    }
}
