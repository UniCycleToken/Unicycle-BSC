pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStake {
        uint256 amount;
        uint256 lastUnlockTime;
    }

    address public WETHAddress;
    address public CYCLEWETHAddress;

    uint256 private constant DAILY_MINT_CAP = 100_000 * 10 ** 18;
    uint256 private constant FIRST_DAY_HARD_CAP = 1_500 * 10 ** 18;
    uint256 private constant FIRST_DAY_WALLET_CAP = 15 * 10 ** 18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    mapping(address => uint256[]) private _userParticipateTimes;
    mapping(address => uint256[]) private _userStakeTimes;
    mapping(address => uint256[]) private _userLPStakeTimes;

    uint256 private _lastStakeTime;
    uint256 private _lastLPStakeTime;

    uint256[] private _mintTimes;
    // timestamp => address => data
    mapping(uint256 => mapping(address => uint256)) private _dailyParticipatedETH;
    mapping(uint256 => mapping(address => uint256)) private _dailyStakedCYCLE;
    mapping(uint256 => mapping(address => LPStake)) private _LPStakes;
    // timestamp => data
    mapping(uint256 => uint256) private _dailyTotalParticipatedETH;
    mapping(uint256 => uint256) private _accumulativeStakedCYCLE;
    mapping(uint256 => uint256) private _accumulativeStakedLP;

    address payable private _teamAddress;
    uint256 private _teamETHShare;
    bool private _isLiquidityAdded;

    ICycleToken private _CYCLE;

    event Participate(uint256 amount, uint256 participateTime, address account);
    event TakeShare(uint256 reward, uint256 participateTime, address account);
    event Stake(uint256 amount, uint256 stakeTime, address account);
    event Unstake(uint256 reward, uint256 stakeTime, address account);
    event StakeLP(uint256 amount, uint256 stakeTime, address account);
    event UnstakeLP(uint256 reward, uint256 stakeTime, address account);

    constructor(address cycleTokenAddress, address uniswapV2Router02Address, uint256 mintTime, address payable teamAddress) public {
        require(cycleTokenAddress != address(0), "ZERO ADDRESS");
        require(uniswapV2Router02Address != address(0), "ZERO ADDRESS");
        require(teamAddress != address(0), "ZERO ADDRESS");
        _CYCLE = ICycleToken(cycleTokenAddress);
        _teamAddress = teamAddress;
        _setLastMintTime(mintTime);
        _isLiquidityAdded = false;
        _lastStakeTime = mintTime;
        _lastLPStakeTime = mintTime;
        IUniswapV2Router02 uniswapV2Router02 = IUniswapV2Router02(uniswapV2Router02Address);
        WETHAddress = uniswapV2Router02.WETH();
        address uniswapV2FactoryAddress = uniswapV2Router02.factory();
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2FactoryAddress);
        CYCLEWETHAddress = factory.getPair(WETHAddress, address(_CYCLE));
        if (CYCLEWETHAddress == address(0))
            CYCLEWETHAddress = factory.createPair(WETHAddress, address(_CYCLE));
    }

    function getUserParticipatesData(address user) external view returns (uint256[] memory) {
        return _userParticipateTimes[user];
    }

    function getUserStakesData(address user) external view returns (uint256[] memory) {
        return _userStakeTimes[user];
    }

    function getUserLPStakesData(address user) external view returns (uint256[] memory) {
        return _userLPStakeTimes[user];
    }

    function getCycleAddress() external view returns (address) {
        return address(_CYCLE);
    }

    function getTeamInfo() external onlyOwner view returns (uint256, address) {
        return (_teamETHShare, _teamAddress);
    }

    function getLastLpUnlockTime(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].lastUnlockTime;
    }

    function getAccumulativeCycle() external view returns (uint256) {
        return _accumulativeStakedCYCLE[_lastStakeTime];
    }

    function getAccumulativeLP() external view returns (uint256) {
        return _accumulativeStakedLP[_lastLPStakeTime];
    }

    function getMintTimesLength() external view returns (uint256) {
        return _mintTimes.length;
    }

    function getParticipatedETHAmount(uint256 mintTime, address user) external view returns (uint256) {
        return _dailyParticipatedETH[mintTime][user];
    }

    function getStakedCycle(uint256 stakeTime, address user) external view returns (uint256) {
        return _dailyStakedCYCLE[stakeTime][user];
    }

    function getStakedLP(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].amount;
    }

    function getTotalParticipateAmount(address user) external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < _mintTimes.length; i++) {
            totalEth = totalEth.add(_dailyParticipatedETH[_mintTimes[i]][user]);
        }
        return totalEth;
    }

    function canTakeShare(uint256 mintTime, address user) external view returns (uint256) {
        if (_dailyTotalParticipatedETH[mintTime] > 0) {
            return _dailyParticipatedETH[mintTime][user].mul(DAILY_MINT_CAP).div(_dailyTotalParticipatedETH[mintTime]);
        }
        return 0;
    }

    function canUnstake(uint256 stakeTime, address user) external view returns (uint256) {
        if (_dailyStakedCYCLE[stakeTime][user] > 0 && stakeTime.add(SECONDS_IN_DAY) < block.timestamp) {
            return _calculateCycleStakeReward(stakeTime, user);
        }
        return 0;
    }

    function canUnstakeLP(uint256 stakeTime, address user) external view returns (uint256) {
        if (_LPStakes[stakeTime][user].amount > 0) {
            uint256 lpStakeReward;
            (lpStakeReward,) = _calculateLPStakeReward(stakeTime);
            return lpStakeReward;
        }
        return 0;
    }

    function getLastMintTime() public view returns (uint256) {
        return _mintTimes[_mintTimes.length - 1];
    }

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newLastMintTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            _startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
            _takeTeamETHShare();
        } else if (_mintTimes.length == 1) {
            require(_dailyTotalParticipatedETH[lastMintTime].add(msg.value) <= FIRST_DAY_HARD_CAP, "First day hard cap reached");
            require(_dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value) <= FIRST_DAY_WALLET_CAP, "First day wallet cap reached");
        } 
        _dailyTotalParticipatedETH[lastMintTime] = _dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        _dailyParticipatedETH[lastMintTime][_msgSender()] = _dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
        _teamETHShare = _teamETHShare.add(msg.value.div(20));
        if (_userParticipateTimes[_msgSender()].length > 0) {
            if (_userParticipateTimes[_msgSender()][_userParticipateTimes[_msgSender()].length - 1] != lastMintTime) {
                _userParticipateTimes[_msgSender()].push(lastMintTime);
            }
        } else {
            _userParticipateTimes[_msgSender()].push(lastMintTime);
        }
        emit Participate(msg.value, lastMintTime, _msgSender());
    }

    function takeShare(uint256 mintTime, address user) external {
        require(_dailyParticipatedETH[mintTime][user] > 0, "Nothing to unlock");
        require(mintTime.add(SECONDS_IN_DAY) < block.timestamp, "At least 1 day must pass");
        uint256 participatedAmount = _dailyParticipatedETH[mintTime][user];
        delete _dailyParticipatedETH[mintTime][user];
        uint256 cycleSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
        for (uint256 i = 0; i < _userParticipateTimes[user].length; i++) {
            if (_userParticipateTimes[user][i] == mintTime) {
                _userParticipateTimes[user][i] = _userParticipateTimes[user][_userParticipateTimes[user].length - 1];
                _userParticipateTimes[user].pop();
            }
        }
        _CYCLE.transfer(user, participatedAmount.mul(cycleSharePayout));
        emit TakeShare(participatedAmount.mul(cycleSharePayout), mintTime, user);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        // uint256 lastStakeTime = getLastStakeTime();
        if (stakeTime > _lastStakeTime) {
            _accumulativeStakedCYCLE[stakeTime] = _accumulativeStakedCYCLE[_lastStakeTime];
        }
        _accumulativeStakedCYCLE[stakeTime] = _accumulativeStakedCYCLE[stakeTime].add(amount);
        _dailyStakedCYCLE[stakeTime][_msgSender()] = _dailyStakedCYCLE[stakeTime][_msgSender()].add(amount);
        _lastStakeTime = stakeTime;
        uint256 fivePercentOfStake = amount.div(20);
        _CYCLE.transferFrom(_msgSender(), address(this), amount);
        _CYCLE.burn(amount.sub(fivePercentOfStake));
        if (_userStakeTimes[_msgSender()].length > 0) {
            if (_userStakeTimes[_msgSender()][_userStakeTimes[_msgSender()].length - 1] != stakeTime) {
                _userStakeTimes[_msgSender()].push(stakeTime);
            }
        } else {
            _userStakeTimes[_msgSender()].push(stakeTime);
        }
        emit Stake(amount, stakeTime, _msgSender());
    }

    function unstake(uint256 stakeTime, address payable user) external {
        require(_dailyStakedCYCLE[stakeTime][user] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < block.timestamp, 'At least 1 day must pass');
        uint256 unstakeRewardAmount = _calculateCycleStakeReward(stakeTime, user);
        _accumulativeStakedCYCLE[_lastStakeTime] = _accumulativeStakedCYCLE[_lastStakeTime].sub(_dailyStakedCYCLE[stakeTime][user]);
        delete _dailyStakedCYCLE[stakeTime][user];
        user.transfer(unstakeRewardAmount);
        for (uint256 i = 0; i < _userStakeTimes[user].length; i++) {
            if (_userStakeTimes[user][i] == stakeTime) {
                _userStakeTimes[user][i] = _userStakeTimes[user][_userStakeTimes[user].length - 1];
                _userStakeTimes[user].pop();
            }
        }
        emit Unstake(unstakeRewardAmount, stakeTime, user);
    }

    function stakeLP(address token, uint256 amount) external {
        require(token == CYCLEWETHAddress, 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > _lastLPStakeTime) {
            _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[_lastLPStakeTime];
        }
        _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[stakeTime].add(amount);
        LPStake storage staker = _LPStakes[stakeTime][_msgSender()];
        staker.amount = staker.amount.add(amount);
        staker.lastUnlockTime = stakeTime;
        _lastLPStakeTime = stakeTime;
        if (_userLPStakeTimes[_msgSender()].length > 0) {
            if (_userLPStakeTimes[_msgSender()][_userLPStakeTimes[_msgSender()].length - 1] != stakeTime) {
                _userLPStakeTimes[_msgSender()].push(stakeTime);
            }
        } else {
            _userLPStakeTimes[_msgSender()].push(stakeTime);
        }
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        emit StakeLP(amount, stakeTime, _msgSender());
    }

    function takeLPReward(uint256 stakeTime, address user) public returns (uint256) {
        require(_LPStakes[stakeTime][user].amount > 0, "Nothing to unlock");
        uint256 lpStakeReward;
        uint256 lastStakeTime;
        (lpStakeReward, lastStakeTime) = _calculateLPStakeReward(stakeTime);
        _LPStakes[stakeTime][user].lastUnlockTime = lastStakeTime;
        _CYCLE.transfer(user, lpStakeReward);
        return lastStakeTime;
    }

    function unstakeLP(uint256 stakeTime, address user) external {
        uint256 lastStakeTime = takeLPReward(stakeTime, user);
        if (lastStakeTime.add(SECONDS_IN_DAY * 2) > block.timestamp) {
            _accumulativeStakedLP[_lastLPStakeTime] = _accumulativeStakedLP[_lastLPStakeTime].sub(_LPStakes[stakeTime][user].amount);
            IERC20(CYCLEWETHAddress).transfer(user, _LPStakes[stakeTime][user].amount);
            delete _LPStakes[stakeTime][user];
        }
    }

    function _getRightStakeTime() private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newStakeTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            return newStakeTime;
        }
        return lastMintTime;
    }

    function _calculateCycleStakeReward(uint256 stakeTime, address user) private view returns (uint256) {
        uint256 cycleStakeReward;
        uint256 accumulativeDailyStakedCycle = _accumulativeStakedCYCLE[stakeTime];
        uint256 amountStaked = _dailyStakedCYCLE[stakeTime][user];
        for (uint256 i = stakeTime; i <= block.timestamp && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (_dailyTotalParticipatedETH[i] > 0) {
                accumulativeDailyStakedCycle = _accumulativeStakedCYCLE[i] == 0 ? accumulativeDailyStakedCycle : _accumulativeStakedCYCLE[i];
                cycleStakeReward = cycleStakeReward.add(
                    _dailyTotalParticipatedETH[i]
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedCycle)
                );
            }
        }
        return cycleStakeReward.mul(95).div(100);
    }

    function _calculateLPStakeReward(uint256 stakeTime) private view returns (uint256, uint256) {
        uint256 lpStakeReward;
        uint256 accumulativeDailyStakedLP = _accumulativeStakedLP[stakeTime];
        uint256 amountStaked = _LPStakes[stakeTime][_msgSender()].amount;
        uint256 lastUnlockTime = _LPStakes[stakeTime][_msgSender()].lastUnlockTime;
        for (;lastUnlockTime <= block.timestamp ;) {
            accumulativeDailyStakedLP = _accumulativeStakedLP[lastUnlockTime] == 0 ? accumulativeDailyStakedLP : _accumulativeStakedLP[lastUnlockTime];
            if (_dailyTotalParticipatedETH[lastUnlockTime] > 0) {
                lpStakeReward = lpStakeReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedLP)
                );
            }
            if (gasleft() < 100000) {
                return(lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
            }
            lastUnlockTime = lastUnlockTime.add(SECONDS_IN_DAY);
        }
        return (lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
    }

    function _takeTeamETHShare() private {
        uint256 teamETHShare = _teamETHShare;
        _teamETHShare = 0;
        if (!_isLiquidityAdded && _mintTimes[1].add(SECONDS_IN_DAY) <= block.timestamp) {
            // mint tokens for first day
            _CYCLE.mint(50_000 * 10 ** 18);
            // (5% + 95%) / 2
            teamETHShare = teamETHShare.add(_dailyTotalParticipatedETH[_mintTimes[1]].mul(95).div(100)).div(2);

            IUniswapV2Pair CYCLEWETH = IUniswapV2Pair(CYCLEWETHAddress);
            IWETH WETH = IWETH(WETHAddress);
            WETH.deposit{ value : teamETHShare }();

            uint256 lpMinted = CYCLEWETH.balanceOf(_teamAddress);

            WETH.transfer(CYCLEWETHAddress, teamETHShare);
            _CYCLE.transfer(CYCLEWETHAddress, 50_000 * 10 ** 18);
            CYCLEWETH.mint(_teamAddress);

            lpMinted = CYCLEWETH.balanceOf(_teamAddress).sub(lpMinted);
            require(lpMinted > 0, "liquidity add failed");

            _isLiquidityAdded = true;
        }
        _teamAddress.transfer(teamETHShare);
    }

    function _setLastMintTime(uint256 mintTime) private {
        _mintTimes.push(mintTime);
    }

    function _startNextRound(uint256 startTime) private {
        _setLastMintTime(startTime);
        _CYCLE.mint(DAILY_MINT_CAP);
    }
}
