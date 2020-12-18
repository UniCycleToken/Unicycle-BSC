pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Interfaces.sol";


contract FakeAuction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStaker {
        uint256 amountStaked;
        uint256 lastUnlockTime;
    }

    struct DailyTotalStakedUnic {
        uint256 amount;
        uint256 accumulative;
    }

    uint256 public constant DAILY_MINT_CAP = 2_500_000_000_000_000_000_000_000;
    uint256 public constant PERCENT_100 = 10**18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    uint256[] public mintTimes;
    mapping(uint256 => mapping(address => uint256)) public dailyStakedUnic;
    mapping(uint256 => DailyTotalStakedUnic) public dailyTotalStakedUnic;

    mapping(uint256 => mapping(address => uint256)) public dailyParticipatedETH;
    mapping(uint256 => uint256) public dailyTotalParticipatedETH;

    mapping(uint256 => mapping(address => LPStaker)) LPStakers;
    mapping(uint256 => uint256) public dailyTotalStakedLP;

    IUnicToken internal _unicToken;

    constructor(address unicTokenAddress, uint256 mintTime) public {
        require(unicTokenAddress != 0x0000000000000000000000000000000000000000, "ZERO ADDRESS");
        _unicToken = IUnicToken(unicTokenAddress);
        setLastMintTime(mintTime);
    }

    function getLastMintTime() public view returns (uint256) {
        if (mintTimes.length > 0) {
            return mintTimes[mintTimes.length - 1];
        }
        return 0;
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
        return dailyTotalStakedUnic[stakeTime].amount;
    }

    function getDailyTotalStakedUnicAccumulative(uint256 stakeTime) external view returns (uint256) {
        return dailyTotalStakedUnic[stakeTime].accumulative;
    }

    function getStakedUnic(uint256 stakeTime) external view returns (uint256) {
        return dailyStakedUnic[stakeTime][_msgSender()];
    }

    function getStakedLP(uint256 stakeTime) external view returns (uint256) {
        return LPStakers[stakeTime][_msgSender()].amountStaked;
    }

    function getDailyTotalStakedLP(uint256 stakeTime) external view returns (uint256) {
        return dailyTotalStakedLP[stakeTime];
    }

    function getLastLPRewardUnlockTime(uint256 stakeTime) external view returns (uint256) {
        return LPStakers[stakeTime][_msgSender()].lastUnlockTime;
    }

    function getTotalParticipateAmount() external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < mintTimes.length; i++) {
            totalEth = totalEth.add(dailyParticipatedETH[mintTimes[i]][_msgSender()]);
        }
        return totalEth;
    }

    function canUnlockTokens(uint256 mintTime) external view returns (uint256) {
        uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        return dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout);
    }

    function canUnStake(uint256 stakeTime) external view returns (uint256) {
        uint256 i;
        uint256 totalStakeEarnings;
        for (i = stakeTime; i <= now && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (dailyTotalParticipatedETH[i] > 0) {
                uint256 stakeEarningsPercent = dailyStakedUnic[stakeTime][_msgSender()]
                    .mul(PERCENT_100)
                    .div(dailyTotalStakedUnic[i].amount > 0 ? dailyTotalStakedUnic[i].amount.add(stakeTime != i ? dailyTotalStakedUnic[stakeTime].amount : 0) : dailyTotalStakedUnic[stakeTime].amount)
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
        return totalStakeEarnings;
    }

    function canUnlockLPReward(uint256 stakeTime) external view returns (uint256) {
        LPStaker memory staker = LPStakers[stakeTime][_msgSender()];
        uint256 i;
        uint256 totalUnlockReward;
        for (i = staker.lastUnlockTime; i <= now; i += SECONDS_IN_DAY) {
            if (dailyTotalParticipatedETH[i] > 0) {
                uint256 lpRewardPercent = LPStakers[stakeTime][_msgSender()].amountStaked
                    .mul(PERCENT_100)
                    .div(dailyTotalStakedLP[i] > 0 ? dailyTotalStakedLP[i].add(stakeTime != i ? dailyTotalStakedLP[stakeTime] : 0) : dailyTotalStakedLP[stakeTime])
                    .mul(100)
                    .div(PERCENT_100);
                totalUnlockReward = totalUnlockReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(lpRewardPercent)
                        .div(PERCENT_100)
                );
            }
        }
        return totalUnlockReward;
    }

    function startNextRound(uint256 startTime) internal {
        setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }

    function participate(uint256 callTime) external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= callTime) {
            uint256 newLastMintTime = lastMintTime.add(((callTime.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
        }
        dailyTotalParticipatedETH[lastMintTime] = dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        dailyParticipatedETH[lastMintTime][_msgSender()] = dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
    }

    function unlockTokens(uint256 mintTime, uint256 callTime) public {
        require(dailyParticipatedETH[mintTime][_msgSender()] > 0, "Nothing to unlock");
        require(mintTime.add(SECONDS_IN_DAY) <= callTime);
        uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout));
    }

    function stake(uint256 amount, uint256 callTime) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = getRightStakeTime(callTime);
        dailyTotalStakedUnic[stakeTime].amount = dailyTotalStakedUnic[stakeTime].amount.add(amount);
        dailyTotalStakedUnic[stakeTime].accumulative = dailyTotalStakedUnic[stakeTime].accumulative.add(amount);
        dailyStakedUnic[stakeTime][_msgSender()] = dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    function unStake(uint256 stakeTime, uint256 callTime) external {
        require(dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < callTime, 'At least 1 day must pass');
        uint256 i;
        uint256 totalStakeEarnings;
        for (i = stakeTime; i <= callTime && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (dailyTotalParticipatedETH[i] > 0) {
                uint256 stakeEarningsPercent = dailyStakedUnic[stakeTime][_msgSender()]
                    .mul(PERCENT_100)
                    .div(dailyTotalStakedUnic[i].amount > 0 ? dailyTotalStakedUnic[i].amount.add(stakeTime != i ? dailyTotalStakedUnic[stakeTime].amount : 0) : dailyTotalStakedUnic[stakeTime].amount)
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
        delete dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(totalStakeEarnings);
    }

    function stakeLP(address token, uint256 amount, uint256 callTime) external {
        require(_unicToken.isBlacklisted(token), 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = getRightStakeTime(callTime);
        dailyTotalStakedLP[stakeTime] = dailyTotalStakedLP[stakeTime].add(amount);
        LPStaker storage staker = LPStakers[stakeTime][_msgSender()];
        staker.amountStaked = staker.amountStaked.add(amount);
        staker.lastUnlockTime = stakeTime;
        ERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function unlockLPReward(uint256 stakeTime, uint256 callTime) external {
        require(LPStakers[stakeTime][_msgSender()].amountStaked > 0, "Nothing to unlock");
        LPStaker memory staker = LPStakers[stakeTime][_msgSender()];
        uint256 i;
        uint256 totalUnlockReward;
        for (i = staker.lastUnlockTime; i <= callTime; i += SECONDS_IN_DAY) {
            if (dailyTotalParticipatedETH[i] > 0) {
                uint256 lpRewardPercent = LPStakers[stakeTime][_msgSender()].amountStaked
                    .mul(PERCENT_100)
                    .div(dailyTotalStakedLP[i] > 0 ? dailyTotalStakedLP[i].add(stakeTime != i ? dailyTotalStakedLP[stakeTime] : 0) : dailyTotalStakedLP[stakeTime])
                    .mul(100)
                    .div(PERCENT_100);
                totalUnlockReward = totalUnlockReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(lpRewardPercent)
                        .div(PERCENT_100)
                );
            }
        }
        staker.lastUnlockTime = getRightStakeTime(callTime);
        _unicToken.transfer(_msgSender(), totalUnlockReward);
    }

    function getRightStakeTime(uint256 callTime) private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= callTime) {
            uint256 newMintTime = lastMintTime.add(((callTime.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            dailyStakedUnic[newMintTime].accumulative = dailyStakedUnic[lastMintTime].accumulative;
            return newMintTime;
        }
        return lastMintTime;
    }
}
