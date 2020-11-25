pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct AuctionParticipant {
        address payable participantAddress;
        uint256 amountETHParticipated;
    }

    struct Stake {
        uint256 unicStaked;
        uint256 ethReward;
        uint256 stakeEndTime;
    }

    struct Staker {
        uint256 totalStaked;
        Stake[] stakes;
    }

    Staker[] public activeStakers;
    mapping(address => uint256) activeStakersIds;
    
    uint256 public _totalStakedUnic;
    uint256 public _totalAuctionedETH;
    IUnicToken internal _unicToken;

    uint256 public MINT_CAP_UNIC_CONST = 2500000000000000000000000;
    AuctionParticipant[] public participants;


    constructor (address unicTokenAddress) public {
        _unicToken = IUnicToken(unicTokenAddress);
    }

    function getNumOfStakes() external view returns (uint256) {
        return activeStakers[activeStakersIds[_msgSender()] - 1].stakes.length;
    }


    function getStakeInfo(uint256 stakeIndex) external view returns (uint256, uint256, uint256) {
        Stake memory stakeInfo = activeStakers[activeStakersIds[_msgSender()] - 1].stakes[stakeIndex];
        return (stakeInfo.unicStaked, stakeInfo.ethReward, stakeInfo.stakeEndTime);
    }


    function getAuctionInfo() external view onlyOwner returns (address, uint256) {
        return (address(_unicToken), _totalAuctionedETH);
    }

    function participate() external payable {
        _totalAuctionedETH = _totalAuctionedETH.add(msg.value);
        AuctionParticipant memory participant;
        participant.participantAddress = _msgSender();
        participant.amountETHParticipated = msg.value;
        participants.push(participant);
    }

    // FOR STAKING
    function stake(uint256 amount, uint256 duration) external {
        // check for balance and allowance
        require(amount <= _unicToken.balanceOf(_msgSender()), "Insufficient balance");
        require(_unicToken.allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
        // add to address aray for later ethReward payout
        uint256 id = activeStakersIds[_msgSender()];
        if (id == 0) {
            activeStakers.push();    
            id = activeStakers.length;
            activeStakersIds[_msgSender()] = id;
        }
        // modify stakers
        Staker storage staker = activeStakers[id - 1];
        staker.totalStaked = staker.totalStaked.add(amount);
        Stake memory newStake;
        newStake.unicStaked = amount;
        newStake.stakeEndTime = block.timestamp.add(duration.mul(86400));
        staker.stakes.push(newStake);
        // modify storage
        _totalStakedUnic = _totalStakedUnic.add(amount);
        // TODO: transfer 5% to LP stakers
        uint256 tokensForLp = amount.div(20);
        //transfer tokens for later burn
        _unicToken.transferFrom(_msgSender(), address(this), amount.sub(tokensForLp));
    }

    function unStake(uint256 stakeIndex) external {
        Staker storage currentStaker = activeStakers[activeStakersIds[_msgSender()] - 1];
        require(currentStaker.stakes.length > 0, "No staked unics");
        require(currentStaker.stakes[stakeIndex].stakeEndTime > 0, "No stake with this index");

        _msgSender().transfer(currentStaker.stakes[stakeIndex].ethReward);
        if (stakeIndex != currentStaker.stakes.length - 1) {
            currentStaker.stakes[stakeIndex] = currentStaker.stakes[currentStaker.stakes.length - 1];
            delete currentStaker.stakes[currentStaker.stakes.length - 1];
        } else {
            delete currentStaker.stakes[stakeIndex];
        }
        
    //     Staker[] public activeStakers;
    // mapping(address => uint256) activeStakersIds;
        if (currentStaker.stakes.length == 0) {
            currentStaker = activeStakers[activeStakers.length -1];
            activeStakers.pop();
        }
        // TODO: algorith for ETH payout
    }

    function unlockTokens() public {
        uint256 unicPercentPayout = MINT_CAP_UNIC_CONST.div(_totalAuctionedETH);
        for (uint256 i = 0; i < participants.length; i++) {
            _unicToken.transfer(participants[i].participantAddress, participants[i].amountETHParticipated.mul(unicPercentPayout));
        }
        uint256 fivePercentOfETH = _totalAuctionedETH.div(20);
        if (_totalAuctionedETH > 0) {
        // TODO: send to team fivePercentOfETH
        // stakers 95% eth payout
            if (activeStakers.length > 0) {
                for (uint256 i = 0; i < activeStakers.length; i++) {
                    Staker storage currentStaker = activeStakers[i];
                    for (uint j = 0; j < currentStaker.stakes.length; j++) {
                        if (currentStaker.stakes[j].stakeEndTime > block.timestamp) {
                            uint256 currentEthReward = (_totalAuctionedETH.sub(fivePercentOfETH)).mul(10 ** 18).div(_totalStakedUnic).mul(currentStaker.stakes[j].unicStaked);
                            currentStaker.stakes[j].ethReward = currentStaker.stakes[j].ethReward.add(currentEthReward.div(10 ** 18));
                        }
                    }
                }
            }
        }
        delete participants;
        _totalAuctionedETH = 0;
        _totalStakedUnic = 0;
        uint256 balanceToBurn = _unicToken.balanceOf(address(this));
        _unicToken.burn(balanceToBurn);
        _unicToken.mint(MINT_CAP_UNIC_CONST);
    }
}
