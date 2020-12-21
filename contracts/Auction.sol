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
    uint256[] public stakeTimes;
    uint256[] public lpStakeTimes;

    mapping(uint256 => mapping(address => uint256)) public dailyStakedUnic;
    mapping(uint256 => uint256) public accumulativeStakedUnic;

    mapping(uint256 => mapping(address => uint256)) public dailyParticipatedETH;
    mapping(uint256 => uint256) public dailyTotalParticipatedETH;

    mapping(uint256 => mapping(address => LPStaker)) LPStakers;
    mapping(uint256 => uint256) public accumulativeStakedLP;
   

    IUnicToken internal _unicToken;

    constructor(address unicTokenAddress, uint256 mintTime) public {
        require(unicTokenAddress != 0x0000000000000000000000000000000000000000, "ZERO ADDRESS");
        _unicToken = IUnicToken(unicTokenAddress);
        _setLastMintTime(mintTime);
    }

    function getLastLpUnlockTime(uint256 stakeTime) external view returns (uint256) {
        return LPStakers[stakeTime][_msgSender()].lastUnlockTime;
    }

    function getAccumulativeUnic() external view returns (uint256) {
        return accumulativeStakedUnic[getLastStakeTime()];
    }

    function getAccumulativeLP() external view returns (uint256) {
        return accumulativeStakedLP[getLastLPStakeTime()];
    }

    function getMintTimesLength() external view returns (uint256) {
        return mintTimes.length;
    }

    function getParticipatedETHAmount(uint256 mintTime) public view returns (uint256) {
        return dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getStakedUnic(uint256 stakeTime) external view returns (uint256) {
        return dailyStakedUnic[stakeTime][_msgSender()];
    }

    function getStakedLP(uint256 stakeTime) external view returns (uint256) {
        return LPStakers[stakeTime][_msgSender()].amountStaked;
    }

    // function getDailyTotalStakedLP(uint256 stakeTime) external view returns (uint256) {
    //     return accumulativeStakedLP[stakeTime];
    // }

    function getTotalParticipateAmount() external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < mintTimes.length; i++) {
            totalEth = totalEth.add(dailyParticipatedETH[mintTimes[i]][_msgSender()]);
        }
        return totalEth;
    }

    function canUnlockTokens(uint256 mintTime) external view returns (uint256) {
        if (dailyTotalParticipatedETH[mintTime] > 0) {
            uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
            return dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout);
        }
        return 0;
    }

    function canUnStake(uint256 stakeTime) external view returns (uint256) {
        if (dailyStakedUnic[stakeTime][_msgSender()] > 0 && stakeTime.add(SECONDS_IN_DAY) < now) {
            return _calculateUnicStakeReward(stakeTime);
        }
        return 0;
    }

    function canUnlockLPReward(uint256 stakeTime) external view returns (uint256) {
        if (LPStakers[stakeTime][_msgSender()].amountStaked > 0) {
            return _calculateLPStakeReward(stakeTime);
            
        }
        return 0;
    }

    function getLastMintTime() public view returns (uint256) {
        return mintTimes[mintTimes.length - 1];
    }

    function getLastStakeTime() public view returns (uint256) {
        if (stakeTimes.length > 0) {
            return stakeTimes[stakeTimes.length - 1];
        }
        return 0;
    }

    function getLastLPStakeTime() public view returns (uint256) {
        if (lpStakeTimes.length > 0) {
            return lpStakeTimes[lpStakeTimes.length - 1];
        }
        return 0;
    }

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= now) {
            uint256 newLastMintTime = lastMintTime.add(((now.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            _startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
        }
        dailyTotalParticipatedETH[lastMintTime] = dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        dailyParticipatedETH[lastMintTime][_msgSender()] = dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
    }

    function unlockTokens(uint256 mintTime) external {
        require(dailyParticipatedETH[mintTime][_msgSender()] > 0, "Nothing to unlock");
        // require(mintTime.add(SECONDS_IN_DAY) < now);
        uint256 unicSharePayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > getLastStakeTime()) {
            accumulativeStakedUnic[stakeTime] = accumulativeStakedUnic[stakeTime].add(accumulativeStakedUnic[getLastStakeTime()]);
        }
        accumulativeStakedUnic[stakeTime] = accumulativeStakedUnic[stakeTime].add(amount);
        dailyStakedUnic[stakeTime][_msgSender()] = dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        stakeTimes.push(stakeTime);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    function unStake(uint256 stakeTime) external {
        require(dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < now, 'At least 1 day must pass');
        uint256 unStakeRewardAmount = _calculateUnicStakeReward(stakeTime);
        uint256 lastStakeTime = getLastStakeTime();
        delete dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(unStakeRewardAmount);
        accumulativeStakedUnic[lastStakeTime] = accumulativeStakedUnic[lastStakeTime].sub(dailyStakedUnic[stakeTime][_msgSender()]);
    }

    function stakeLP(address token, uint256 amount) external {
        require(_unicToken.isBlacklisted(token), 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > getLastLPStakeTime()) {
            accumulativeStakedLP[stakeTime] = accumulativeStakedLP[stakeTime].add(accumulativeStakedLP[getLastLPStakeTime()]);
        }
        accumulativeStakedLP[stakeTime] = accumulativeStakedLP[stakeTime].add(amount);
        LPStaker storage staker = LPStakers[stakeTime][_msgSender()];
        staker.amountStaked = staker.amountStaked.add(amount);
        staker.lastUnlockTime = stakeTime;
        lpStakeTimes.push(stakeTime);
        ERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function unlockLPReward(uint256 stakeTime) external {
        require(LPStakers[stakeTime][_msgSender()].amountStaked > 0, "Nothing to unlock");
        uint256 lpStakeReward = _calculateLPStakeReward(stakeTime);
        LPStakers[stakeTime][_msgSender()].lastUnlockTime = _getRightStakeTime();
        _unicToken.transfer(_msgSender(), lpStakeReward);
    }

    function _getRightStakeTime() private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= now) {
            uint256 newStakeTime = lastMintTime.add(((now.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            return newStakeTime;
        }
        return lastMintTime;
    }


    function _calculateUnicStakeReward(uint256 stakeTime) private view returns (uint256) {
        uint256 unicStakeReward;
        uint256 accumulativeDailyStakedUnic = accumulativeStakedUnic[stakeTime];
        for (uint256 i = stakeTime; i <= now && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (dailyTotalParticipatedETH[i] > 0) {
                accumulativeDailyStakedUnic = accumulativeStakedUnic[i] == 0 ? accumulativeDailyStakedUnic : accumulativeStakedUnic[i];
                uint256 stakeEarningsPercent = dailyStakedUnic[stakeTime][_msgSender()]
                    .mul(PERCENT_100)
                    .div(accumulativeDailyStakedUnic)
                    .mul(100)
                    .div(PERCENT_100);
                unicStakeReward = unicStakeReward.add(
                    dailyTotalParticipatedETH[i]
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(stakeEarningsPercent)
                        .div(PERCENT_100)
                );
            }
        }
        return unicStakeReward - unicStakeReward.div(20);
    }

    function _calculateLPStakeReward(uint256 stakeTime) private view returns (uint256) {
        uint256 i;
            uint256 lpStakeReward;
            uint256 accumulativeDailyStakedLP = accumulativeStakedLP[stakeTime];
            for (i = LPStakers[stakeTime][_msgSender()].lastUnlockTime; i <= now; i += SECONDS_IN_DAY) {
                accumulativeDailyStakedLP = accumulativeStakedLP[i] == 0 ? accumulativeDailyStakedLP : accumulativeStakedLP[i];
                if (dailyTotalParticipatedETH[i] > 0) {
                    uint256 lpRewardPercent = LPStakers[stakeTime][_msgSender()].amountStaked
                        .mul(PERCENT_100)
                        .div(accumulativeDailyStakedLP)
                        .mul(100)
                        .div(PERCENT_100);
                    lpStakeReward = lpStakeReward.add(
                        DAILY_MINT_CAP
                            .div(20)
                            .mul(PERCENT_100)
                            .div(100)
                            .mul(lpRewardPercent)
                            .div(PERCENT_100)
                    );
                }
            }
            return lpStakeReward;
    }

    function _setLastMintTime(uint256 mintTime) private {
        mintTimes.push(mintTime);
    }

    function _startNextRound(uint256 startTime) private {
        _setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }
}
