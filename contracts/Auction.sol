pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStaker {
        uint256 amountStaked;
        uint256 lastUnlockTime;
    }

    uint256 public constant DAILY_MINT_CAP = 2_500_000_000_000_000_000_000_000;
    uint256 public constant PERCENT_100 = 10**18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    uint256[] public mintTimes;
    mapping(uint256 => mapping(address => uint256)) public dailyStakedUnic;
    mapping(uint256 => uint256) public dailyTotalStakedUnic;

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

    function getStakedLP(uint256 stakeTime) external view returns (uint256) {
        return LPStakers[stakeTime][_msgSender()].amountStaked;
    }

    function getDailyTotalStakedLP(uint256 stakeTime) external view returns (uint256) {
        return dailyTotalStakedLP[stakeTime];
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

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= now) {
            uint256 newLastMintTime = lastMintTime.add(((now.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
        }
        dailyTotalParticipatedETH[lastMintTime] = dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        dailyParticipatedETH[lastMintTime][_msgSender()] = dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
    }

    function unlockTokens(uint256 mintTime) public {
        require(dailyParticipatedETH[mintTime][_msgSender()] > 0, "Nothing to unlock");
        // require(mintTime.add(SECONDS_IN_DAY) < now);
        uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = getRightStakeTime();
        dailyTotalStakedUnic[stakeTime] = dailyTotalStakedUnic[stakeTime].add(amount);
        dailyStakedUnic[stakeTime][_msgSender()] = dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    function unStake(uint256 stakeTime) external {
        require(dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < now, 'At least 1 day must pass');
        uint256 i;
        uint256 totalStakeEarnings;
        for (i = stakeTime; i <= now && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
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
        // dailyTotalStakedUnic[stakeTime] = dailyTotalStakedUnic[stakeTime].sub(dailyStakedUnic[stakeTime][_msgSender()]);
        delete dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(totalStakeEarnings);
    }

    function stakeLP(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = getRightStakeTime();
        dailyTotalStakedLP[stakeTime] = dailyTotalStakedLP[stakeTime].add(amount);
        LPStaker storage staker = LPStakers[stakeTime][_msgSender()];
        staker.amountStaked = staker.amountStaked.add(amount);
        staker.lastUnlockTime = stakeTime;
    }

    function unlockLPReward(uint256 stakeTime) external {
        require(LPStakers[stakeTime][_msgSender()].amountStaked > 0, "Nothing to unlock");
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
        staker.lastUnlockTime = getRightStakeTime();
        _unicToken.transfer(_msgSender(), totalUnlockReward);
    }

    function getRightStakeTime() private view returns(uint256) {
        if (getLastMintTime().add(SECONDS_IN_DAY) <= now) {
            return getLastMintTime().add(((now.sub(getLastMintTime())).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
        }
        return getLastMintTime();
    }
}
